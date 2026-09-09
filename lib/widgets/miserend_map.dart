import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// A single pin to render on a [MiserendMap].
class MiserendMapMarker {
  const MiserendMapMarker({required this.id, required this.point, this.onTap});

  final Object id;
  final LatLng point;
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
    this.compactAttribution = false,
    this.apiKey,
  });

  static const defaultInitialCenter = LatLng(47.2537659, 19.752314);
  static const double defaultInitialZoom = 8;

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
  final bool compactAttribution;

  /// CARTO API key for the authenticated, single-host tile endpoint. When
  /// null or empty, falls back to the free, key-less, multi-subdomain
  /// endpoint (the default used everywhere in the app).
  final String? apiKey;

  @override
  State<MiserendMap> createState() => _MiserendMapState();
}

class _MiserendMapState extends State<MiserendMap> {
  /// The Térkép tab hands over a pin for all 5000 churches. Converting them to
  /// map markers on every rebuild, such as when a church card opens, is enough
  /// work to drop frames, and the pins themselves only change when the list
  /// does.
  late List<Marker> _mapMarkers = _buildMarkers();

  @override
  void didUpdateWidget(MiserendMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.markers, widget.markers)) {
      _mapMarkers = _buildMarkers();
    }
  }

  List<Marker> _buildMarkers() => widget.markers
      .map((m) => Marker(
            key: ValueKey(m.id),
            point: m.point,
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTap: m.onTap,
              child: const Icon(
                Icons.location_pin,
                color: Colors.red,
                size: 40,
              ),
            ),
          ))
      .toList();

  bool get _hasApiKey => widget.apiKey != null && widget.apiKey!.isNotEmpty;

  String get _tileUrlTemplate => _hasApiKey
      ? 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png?key=${widget.apiKey}'
      : MiserendMap._freeTileUrlTemplate;

  List<String> get _tileSubdomains =>
      _hasApiKey ? const [] : MiserendMap._freeTileSubdomains;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: widget.mapController,
          options: MapOptions(
            initialCenter: widget.initialCenter,
            initialZoom: widget.initialZoom,
            interactionOptions: InteractionOptions(
              flags: widget.interactive
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
