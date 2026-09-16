import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:miserend/colors.dart';

/// A single church to render on a [MiserendMap].
class MiserendMapMarker {
  const MiserendMapMarker({required this.id, required this.point, this.onTap});

  final Object id;
  final LatLng point;

  /// Only ever called while the church shows as a pin. Below
  /// [MiserendMap.pinMinZoom] a tap zooms in instead (spec 0006).
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

  /// Below this the churches are dots rather than pins. All ~5000 of them are
  /// on screen at the country zoom, where 40px pins run into one mass that
  /// says nothing (spec 0006, „Sűrűség-küszöb").
  static const double pinMinZoom = 12;

  /// The pin of miserend.hu, the same mark the webapp uses.
  static const pinAsset = 'assets/images/map_pin.png';

  /// The asset is 111x171; the width keeps that ratio at [_pinHeight].
  static const double _pinHeight = 40;
  static const double _pinWidth = 26;

  /// The church whose card is open stands out from the rest by size alone —
  /// colour is the webapp's denomination language, which this app cannot
  /// speak yet (ADR-0001).
  static const double _selectedPinScale = 1.3;

  static const double _dotDiameter = 8;

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
  /// over none, because a tap on a dot has to move the camera itself.
  late final MapController _controller =
      widget.mapController ?? MapController();

  /// Only the controller this state made is its to dispose of.
  bool get _ownsController => widget.mapController == null;

  late bool _showPins = widget.initialZoom >= MiserendMap.pinMinZoom;

  /// The Térkép tab hands over a pin for all 5000 churches. Converting them to
  /// map markers on every rebuild, such as when a church card opens, is enough
  /// work to drop frames, and the pins themselves only change when the list,
  /// the selection or the zoom side does.
  late List<Marker> _mapMarkers = _buildMarkers();

  @override
  void didUpdateWidget(MiserendMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.markers, widget.markers) ||
        oldWidget.selectedMarkerId != widget.selectedMarkerId) {
      _mapMarkers = _buildMarkers();
    }
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  /// Rebuilds only when the camera crosses [MiserendMap.pinMinZoom], not on
  /// every zoom step.
  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    final showPins = camera.zoom >= MiserendMap.pinMinZoom;
    if (showPins == _showPins) return;
    setState(() {
      _showPins = showPins;
      _mapMarkers = _buildMarkers();
    });
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    Marker? selected;
    for (final m in widget.markers) {
      if (m.id == widget.selectedMarkerId) {
        selected = _churchMarker(m, selected: true);
      } else {
        markers.add(_churchMarker(m, selected: false));
      }
    }
    // Last, so that it paints above every other church.
    if (selected != null) markers.add(selected);
    return markers;
  }

  Marker _churchMarker(MiserendMapMarker m, {required bool selected}) {
    // The selected church keeps its pin however far out the user zooms.
    if (!_showPins && !selected) {
      return Marker(
        key: ValueKey(m.id),
        point: m.point,
        width: MiserendMap._dotDiameter,
        height: MiserendMap._dotDiameter,
        child: GestureDetector(
          // A dot is far too small to aim at, and at the country zoom dozens
          // of them overlap: a tap here means „this area", not „this church".
          onTap: () => _controller.move(m.point, MiserendMap.pinMinZoom),
          child: const DecoratedBox(
            decoration: BoxDecoration(
              color: CustomColors.purple,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }

    final scale = selected ? MiserendMap._selectedPinScale : 1.0;
    return Marker(
      key: ValueKey(m.id),
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

  Marker _userPositionMarker(LatLng point) => Marker(
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
    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: widget.initialCenter,
            initialZoom: widget.initialZoom,
            onTap: widget.onTap == null ? null : (_, __) => widget.onTap!(),
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
            MarkerLayer(markers: _mapMarkers),
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
