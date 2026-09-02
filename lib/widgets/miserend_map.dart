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
class MiserendMap extends StatelessWidget {
  const MiserendMap({
    super.key,
    required this.interactive,
    this.mapController,
    this.initialCenter = defaultInitialCenter,
    this.initialZoom = defaultInitialZoom,
    this.markers = const [],
    this.compactAttribution = false,
  });

  static const defaultInitialCenter = LatLng(47.2537659, 19.752314);
  static const double defaultInitialZoom = 8;

  static const _tileUrlTemplate =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';
  static const _tileSubdomains = ['a', 'b', 'c', 'd'];
  static const _tileMaxZoom = 19.0;
  static const _fullAttribution = '© OpenStreetMap contributors © CARTO';
  static const _compactAttribution = '© OSM © CARTO';

  final bool interactive;
  final MapController? mapController;
  final LatLng initialCenter;
  final double initialZoom;
  final List<MiserendMapMarker> markers;
  final bool compactAttribution;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: initialZoom,
            interactionOptions: InteractionOptions(
              flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: _tileUrlTemplate,
              subdomains: _tileSubdomains,
              maxZoom: _tileMaxZoom,
            ),
            MarkerLayer(
              markers: markers
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
                  .toList(),
            ),
          ],
        ),
        Positioned(
          right: 4,
          bottom: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            color: const Color(0xB3FFFFFF),
            child: Text(
              compactAttribution ? _compactAttribution : _fullAttribution,
              style: const TextStyle(fontSize: 10, color: Colors.black87),
            ),
          ),
        ),
      ],
    );
  }
}
