import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:miserend/database/cache/church_list_entry.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/home/churches/church_card.dart';
import 'package:miserend/home/churches/church_list_loader.dart';
import 'package:miserend/location_provider.dart';
import 'package:miserend/widgets/miserend_map.dart';
import 'package:miserend/widgets/position_unavailable_view.dart';
import 'package:provider/provider.dart';

/// Every church of the cache on the map. Tapping one shows its card from the
/// cache at once and refreshes it in full in the background (ADR-0003).
class MapPage extends StatefulWidget {
  const MapPage({super.key, this.loader, this.location, this.mapController});

  /// Injected by tests; the page builds its own otherwise.
  final ChurchListLoader? loader;
  final LocationProvider? location;
  final MapController? mapController;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with WidgetsBindingObserver {
  static const double _positionZoom = 14;

  late final MapController _controller =
      widget.mapController ?? MapController();
  late final ChurchListLoader _loader = widget.loader ??
      ChurchListLoader(
          onChurchesGone:
              Provider.of<FavoritesService>(context, listen: false).removeAll);
  late final LocationProvider _location =
      widget.location ?? LocationProvider();

  List<MiserendMapMarker> _markers = [];

  /// The card on screen, and the church it is for.
  ChurchList? _card;
  int? _cardChurchId;

  /// Set when the user was sent to the settings from the position SnackBar,
  /// so that coming back tries the position again.
  bool _retryPositionOnResume = false;
  bool _wasInBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMarkers();
    // Quietly: a SnackBar the moment the tab opens would answer a question
    // nobody asked. Without a position the map stays on the country.
    _goToMyPosition(announce: false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_wasInBackground && _retryPositionOnResume) {
          _retryPositionOnResume = false;
          _goToMyPosition(announce: true);
        }
        _wasInBackground = false;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _wasInBackground = true;
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = _card;
    final ChurchListEntry? entry =
        card == null || card.churches.isEmpty ? null : card.churches.first;
    return Stack(
      children: [
        MiserendMap(
          interactive: true,
          mapController: _controller,
          markers: _markers,
          apiKey: const String.fromEnvironment('CARTO_API_KEY'),
        ),
        if (entry != null)
          Column(
            children: [
              Expanded(child: Container()),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ChurchCard(
                  entry: entry,
                  failure: card!.failure,
                  dataAsOf: card.dataAsOf,
                ),
              ),
            ],
          ),
        Positioned(
          right: 8,
          bottom: entry != null ? 192 : 8,
          child: FloatingActionButton(
            onPressed: () => _goToMyPosition(announce: true),
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }

  Future<void> _loadMarkers() async {
    final locations = await _loader.churchLocations();
    if (!mounted) return;
    setState(() {
      _markers = locations
          .map((church) => MiserendMapMarker(
                id: church.id,
                point: LatLng(church.lat, church.lon),
                onTap: () => _showChurchCard(church.id),
              ))
          .toList();
    });
  }

  /// Moves to the user's position. When there is none and [announce] is set,
  /// says why in a SnackBar, with the way out as its action.
  Future<void> _goToMyPosition({required bool announce}) async {
    final result = await _location.currentPosition();
    if (!mounted) return;
    switch (result) {
      case PositionFound(:final position):
        _controller.move(
            LatLng(position.latitude, position.longitude), _positionZoom);
      case PositionUnavailable(:final reason):
        if (!announce) return;
        final action = PositionUnavailableView.action(
            reason, _location, () => _goToMyPosition(announce: true));
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(SnackBar(
          content: Text(PositionUnavailableView.message(
              reason, 'A helyzeted mutatásához')),
          action: action == null
              ? null
              : SnackBarAction(
                  label: action.$1,
                  onPressed: () {
                    _retryPositionOnResume =
                        reason != PositionUnavailableReason.permissionDenied;
                    action.$2();
                  },
                ),
        ));
    }
  }

  Future<void> _showChurchCard(int churchId) async {
    final query = ChurchCardQuery(churchId);
    _cardChurchId = churchId;

    final cached = await _loader.load(query);
    if (!mounted || _cardChurchId != churchId) return;
    setState(() => _card = cached);

    final refreshed = await _loader.refresh(query, cached.churches);
    if (!mounted || _cardChurchId != churchId) return;
    if (refreshed.removed.contains(churchId)) {
      setState(() {
        _card = null;
        _cardChurchId = null;
        _markers = _markers.where((m) => m.id != churchId).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ez a templom már nem szerepel a miserend.hu-n.')));
      return;
    }
    setState(() => _card = refreshed);
  }
}
