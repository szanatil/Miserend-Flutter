import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:miserend/colors.dart';

/// A single church to render on a [MiserendMap].
class MiserendMapMarker {
  const MiserendMapMarker({required this.id, required this.point, this.onTap});

  final Object id;
  final LatLng point;

  /// Called for a tap on the church's own pin — also one opened out of a group
  /// on a single spot. A tap on a group zooms in instead (spec 0012).
  final VoidCallback? onTap;
}

/// Shared CartoDB Voyager map, used by the Térkép tab and the church detail
/// location card. This is the only place the tile URL and attribution text
/// are defined.
class MiserendMap extends StatefulWidget {
  const MiserendMap({
    super.key,
    required this.interactive,
    this.mapController,
    this.initialCenter = defaultInitialCenter,
    this.initialZoom = defaultInitialZoom,
    this.markers = const [],
    this.selectedMarkerId,
    this.userPosition,
    this.compactAttribution = false,
    this.apiKey,
    this.onTap,
  });

  static const defaultInitialCenter = LatLng(47.2537659, 19.752314);
  static const double defaultInitialZoom = 8;

  /// The pin of miserend.hu, the same mark the webapp uses.
  static const pinAsset = 'assets/images/map_pin.png';

  /// The key of the church [id]'s pin, wherever it is drawn: on its own, in
  /// a group opened out, or as the selected one.
  static Key markerKey(Object id) => ValueKey<Object>(id);

  /// The key of the user's own mark.
  static const Key userPositionKey = ValueKey('miserend-map-user-position');

  /// The asset is 111x171; the width keeps that ratio at [_pinHeight].
  static const double _pinHeight = 40;
  static const double _pinWidth = 26;

  /// The church whose card is open stands out from the rest by size alone —
  /// colour is the webapp's denomination language, which this app cannot
  /// speak yet (ADR-0001).
  static const double _selectedPinScale = 1.3;

  /// Churches closer than this on screen form a group: a pin's height, the
  /// distance at which two pins stop covering each other (spec 0012,
  /// „Csoportosítás").
  static const int _groupRadius = 40;

  /// The group's circle grows with its count in a few steps, so that a region
  /// full of churches reads as such at a glance. Each entry is the smallest
  /// count that gets the diameter.
  static const List<({int minCount, double diameter})> _groupDiameters = [
    (minCount: 1000, diameter: 56),
    (minCount: 100, diameter: 48),
    (minCount: 10, diameter: 42),
    (minCount: 0, diameter: 36),
  ];

  /// How far a large font may grow a group's circle. Past this the circles
  /// would cover the map they are meant to summarise.
  static const double _maxGroupTextScale = 1.6;

  /// Where the churches on one spot open out to, from the spot. Far enough
  /// apart for each pin to be a target of its own.
  static const int _spreadRadius = 36;

  /// The closest zoom the map allows. The tiles end there, and groups that
  /// hold together even there are the ones that open out on a tap.
  static const double _maxZoom = _tileMaxZoom;

  /// The user's own mark never changes size with the zoom: it is the one
  /// fixed point the eye returns to (CONTEXT.md, „Helyzet").
  static const double _userDotDiameter = 18;

  /// Room for the ring and the shadow around [_userDotDiameter], so that the
  /// marker box does not cut them off.
  static const double _userDotBox = 26;

  static const Color _userDotColor = Color(0xFF1A73E8);

  static const _freeTileUrlTemplate =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';
  static const _freeTileSubdomains = ['a', 'b', 'c', 'd'];
  static const _tileMaxZoom = 19.0;
  static const _fullAttribution = '© OpenStreetMap contributors © CARTO';
  static const _compactAttribution = '© OSM © CARTO';

  final bool interactive;
  final MapController? mapController;
  final LatLng initialCenter;
  final double initialZoom;
  final List<MiserendMapMarker> markers;

  /// The church whose card is open, drawn as an enlarged pin above the rest
  /// at every zoom, so that the card and the map do not lose each other.
  final Object? selectedMarkerId;

  /// The user's **helyzet** (CONTEXT.md), or null while it is not known. Kept
  /// apart from [markers] because a position is not a church — and because
  /// folding it in would rebuild all ~5000 church markers on every fix.
  final LatLng? userPosition;

  final bool compactAttribution;

  /// CARTO API key for the authenticated, single-host tile endpoint. When
  /// null or empty, falls back to the free, key-less, multi-subdomain
  /// endpoint (the default used everywhere in the app).
  final String? apiKey;

  /// Called for a tap on the map itself, not on a marker.
  final VoidCallback? onTap;

  @override
  State<MiserendMap> createState() => _MiserendMapState();
}

class _MiserendMapState extends State<MiserendMap> {
  /// Built here rather than left to [FlutterMap] even when the caller hands
  /// over none, so that the camera is one the state knows.
  late final MapController _controller =
      widget.mapController ?? MapController();

  /// Only the controller this state made is its to dispose of.
  bool get _ownsController => widget.mapController == null;

  /// The Térkép tab hands over a pin for all 5000 churches. The group layer
  /// sorts them into groups for every zoom whenever this list is a new one,
  /// so it is only rebuilt when the churches, the selection or the text size
  /// change — not, for example, when a church card opens.
  late List<Marker> _groupedMarkers;

  /// The selected church's pin, kept out of the groups (spec 0012,
  /// „Kiválasztott templom").
  Marker? _selectedMarker;

  /// The text scale the group circles were sized for.
  double? _groupTextScale;

  /// Bumped to close a group opened out on a spot. The group layer offers no
  /// way to close one from outside, so it is built anew.
  int _groupLayerGeneration = 0;

  /// Whether a group may be open on a spot: one was tapped since the user
  /// last zoomed by hand. Only then is a tap on the map worth rebuilding the
  /// group layer for.
  bool _mayBeSpread = false;

  /// The zoom the camera was last seen at, to tell a zoom from a pan.
  double? _lastZoom;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final textScale = MediaQuery.textScalerOf(
      context,
    ).scale(1).clamp(1.0, MiserendMap._maxGroupTextScale);
    if (textScale == _groupTextScale) return;
    _groupTextScale = textScale;
    _splitMarkers();
  }

  @override
  void didUpdateWidget(MiserendMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.markers, widget.markers) ||
        oldWidget.selectedMarkerId != widget.selectedMarkerId) {
      _splitMarkers();
    }
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  /// Sorts the churches into the ones the group layer shows and the selected
  /// one, which it leaves out.
  void _splitMarkers() {
    final grouped = <Marker>[];
    Marker? selected;
    for (final m in widget.markers) {
      if (m.id == widget.selectedMarkerId) {
        selected = _churchMarker(m, selected: true);
      } else {
        grouped.add(_churchMarker(m, selected: false));
      }
    }
    _groupedMarkers = grouped;
    _selectedMarker = selected;
  }

  Marker _churchMarker(MiserendMapMarker m, {required bool selected}) {
    final scale = selected ? MiserendMap._selectedPinScale : 1.0;
    return Marker(
      key: MiserendMap.markerKey(m.id),
      point: m.point,
      width: MiserendMap._pinWidth * scale,
      height: MiserendMap._pinHeight * scale,
      // Puts the child's bottom edge on the point, which for a pin is its tip.
      alignment: Alignment.topCenter,
      child: GestureDetector(
        // The selected church's card is already open; tapping it again would
        // only refetch what is on screen.
        onTap: selected ? null : m.onTap,
        child: Image.asset(
          MiserendMap.pinAsset,
          width: MiserendMap._pinWidth * scale,
          height: MiserendMap._pinHeight * scale,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Size _groupSize(List<Marker> markers) {
    final count = markers.length;
    final step = MiserendMap._groupDiameters.firstWhere(
      (step) => count >= step.minCount,
    );
    return Size.square(step.diameter * (_groupTextScale ?? 1));
  }

  Widget _groupCircle(BuildContext context, List<Marker> markers) =>
      DecoratedBox(
        decoration: BoxDecoration(
          color: CustomColors.purple,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          // The circle already grew with the text size, up to a limit; past it
          // the count shrinks to fit rather than spill out of the circle.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${markers.length}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );

  /// A zoom by hand closes an open group by itself. The camera move of a
  /// group tap does not count: the group may open out only after it, at the
  /// whole zoom step it moved to.
  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (hasGesture && camera.zoom != _lastZoom) _mayBeSpread = false;
    _lastZoom = camera.zoom;
  }

  void _onMapTap() {
    if (_mayBeSpread) {
      setState(() {
        _mayBeSpread = false;
        _groupLayerGeneration++;
      });
    }
    widget.onTap?.call();
  }

  Marker _userPositionMarker(LatLng point) => Marker(
    key: MiserendMap.userPositionKey,
    point: point,
    width: MiserendMap._userDotBox,
    height: MiserendMap._userDotBox,
    child: Center(
      child: Container(
        width: MiserendMap._userDotDiameter,
        height: MiserendMap._userDotDiameter,
        decoration: BoxDecoration(
          color: MiserendMap._userDotColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 4, spreadRadius: 1),
          ],
        ),
      ),
    ),
  );

  bool get _hasApiKey => widget.apiKey != null && widget.apiKey!.isNotEmpty;

  String get _tileUrlTemplate =>
      _hasApiKey
          ? 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png?key=${widget.apiKey}'
          : MiserendMap._freeTileUrlTemplate;

  List<String> get _tileSubdomains =>
      _hasApiKey ? const [] : MiserendMap._freeTileSubdomains;

  @override
  Widget build(BuildContext context) {
    final userPosition = widget.userPosition;
    final selected = _selectedMarker;
    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: widget.initialCenter,
            initialZoom: widget.initialZoom,
            maxZoom: MiserendMap._maxZoom,
            onTap: (_, __) => _onMapTap(),
            onPositionChanged: _onPositionChanged,
            interactionOptions: InteractionOptions(
              flags:
                  widget.interactive
                      ? InteractiveFlag.all
                      : InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: _tileUrlTemplate,
              subdomains: _tileSubdomains,
              maxZoom: MiserendMap._tileMaxZoom,
            ),
            MarkerClusterLayerWidget(
              key: ValueKey(_groupLayerGeneration),
              options: MarkerClusterLayerOptions(
                markers: _groupedMarkers,
                maxClusterRadius: MiserendMap._groupRadius,
                computeSize: _groupSize,
                builder: _groupCircle,
                // A tap zooms in on the group until it falls apart; one that
                // holds together at the closest zoom opens out instead.
                maxZoom: MiserendMap._maxZoom,
                spiderfyCircleRadius: MiserendMap._spreadRadius,
                showPolygon: false,
                // The pins keep their own tap; the map does not move under
                // the finger when a church is picked.
                markerChildBehavior: true,
                centerMarkerOnClick: false,
                onClusterTap: (_) => _mayBeSpread = true,
              ),
            ),
            // Its own layer, after the groups: the church whose card is open
            // is never folded into a group or painted over by one.
            if (selected != null) MarkerLayer(markers: [selected]),
            // Its own layer, drawn last: the user's mark is never hidden by a
            // church, and a new fix does not touch the church markers.
            if (userPosition != null)
              MarkerLayer(markers: [_userPositionMarker(userPosition)]),
          ],
        ),
        Positioned(
          right: 4,
          bottom: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            color: const Color(0xB3FFFFFF),
            child: Text(
              widget.compactAttribution
                  ? MiserendMap._compactAttribution
                  : MiserendMap._fullAttribution,
              style: const TextStyle(fontSize: 10, color: Colors.black87),
            ),
          ),
        ),
      ],
    );
  }
}
