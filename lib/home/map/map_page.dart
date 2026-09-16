import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:miserend/database/cache/church_list_entry.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/home/churches/church_card.dart';
import 'package:miserend/home/churches/church_list_loader.dart';
import 'package:miserend/home/map/widgets/position_unavailable_banner.dart';
import 'package:miserend/location_provider.dart';
import 'package:miserend/widgets/miserend_map.dart';
import 'package:provider/provider.dart';

/// Every church of the cache on the map. Tapping one shows its card from the
/// cache at once and refreshes it in full in the background (ADR-0003).
class MapPage extends StatefulWidget {
  const MapPage({
    super.key,
    this.isActive = true,
    this.loader,
    this.location,
    this.mapController,
  });

  /// Whether the tab is the one on screen. The home screen keeps every opened
  /// tab alive in an IndexedStack, so the page cannot tell by itself — and it
  /// has to know, because the position may have been allowed in the phone's
  /// settings while another tab was in front.
  final bool isActive;

  /// Injected by tests; the page builds its own otherwise.
  final ChurchListLoader? loader;

  /// Injected by tests; the page builds its own otherwise.
  final LocationProvider? location;

  /// Injected by tests; the page builds its own otherwise.
  final MapController? mapController;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with WidgetsBindingObserver {
  static const double _positionZoom = 14;

  late final MapController _controller =
      widget.mapController ?? MapController();
  late final ChurchListLoader _loader =
      widget.loader ??
      ChurchListLoader(
        onChurchesGone:
            Provider.of<FavoritesService>(context, listen: false).removeAll,
      );
  late final LocationProvider _location = widget.location ?? LocationProvider();

  List<MiserendMapMarker> _markers = [];

  /// Bumped per marker load, so that a slow read cannot draw older markers
  /// over newer ones.
  int _markersLoadId = 0;

  /// The card on screen, and the church it is for.
  ChurchList? _card;
  int? _cardChurchId;

  /// Where the user is, as of the last position that came back (CONTEXT.md,
  /// „Helyzet"). Null while it is not known — an older position may have been
  /// recorded in another town, so a mark left behind would be a lie.
  LatLng? _userPosition;

  /// Why there is no position, while the strip says so. Part of the page's
  /// state rather than a message fired and forgotten, so that the strip going
  /// up, going away and being closed all follow from [build].
  PositionUnavailableReason? _positionUnavailableReason;

  /// Set when the app actually left the screen, so that the brief
  /// inactive/resumed flicker of a system dialog does not count as coming
  /// back.
  bool _wasInBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The tab stays alive underneath the others, so the markers follow every
    // answer written to the cache, not only the ones this page asked for.
    _loader.churchesWritten.addListener(_loadMarkers);
    _loadMarkers();
    // Quietly: a strip the moment the tab opens would answer a question
    // nobody asked. Without a position the map stays on the country.
    _refreshPosition();
  }

  @override
  void dispose() {
    _loader.churchesWritten.removeListener(_loadMarkers);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back to the tab is a chance for the position to have changed
  /// behind the map's back: the user may have allowed it in the phone's
  /// settings from another tab's button.
  @override
  void didUpdateWidget(MapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _refreshPosition();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // Whoever sent the user to the settings, the map checks again — the
        // position-bound lists do the same (near_churches_page.dart).
        if (_wasInBackground && widget.isActive) _refreshPosition();
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
    final noPosition = _positionUnavailableReason;
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              MiserendMap(
                interactive: true,
                mapController: _controller,
                markers: _markers,
                selectedMarkerId: _cardChurchId,
                userPosition: _userPosition,
                apiKey: const String.fromEnvironment('CARTO_API_KEY'),
                onTap: _closeCard,
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
                  onPressed: _goToMyPosition,
                  child: const Icon(Icons.my_location),
                ),
              ),
            ],
          ),
        ),
        // The strip takes its own room under the map rather than lying over
        // it, so the church card and the my-position button stay whole.
        if (noPosition != null)
          PositionUnavailableBanner(
            reason: noPosition,
            location: _location,
            onRetry: _goToMyPosition,
            onClose: () => setState(() => _positionUnavailableReason = null),
          ),
      ],
    );
  }

  Future<void> _loadMarkers() async {
    final loadId = ++_markersLoadId;
    final locations = await _loader.churchLocations();
    if (!mounted || loadId != _markersLoadId) return;
    setState(() {
      _markers =
          locations
              .map(
                (church) => MiserendMapMarker(
                  id: church.id,
                  point: LatLng(church.lat, church.lon),
                  onTap: () => _showChurchCard(church.id),
                ),
              )
              .toList();
    });
  }

  /// The my-position button: brings the camera along whatever is on screen,
  /// and says why when there is no position.
  Future<void> _goToMyPosition() =>
      _updatePosition(announce: true, follow: true);

  /// Opening the tab, coming back to it, and returning to the app: checks the
  /// position without asking the user anything. The camera only follows while
  /// the user cannot see themselves — the first fix, or the first after the
  /// position was lost — so that coming back does not drag the map away from
  /// wherever it was left.
  Future<void> _refreshPosition() =>
      _updatePosition(announce: false, follow: _userPosition == null);

  /// [announce] raises the strip when there is no position; without it the
  /// screen stays quiet, and a strip already up stays up.
  Future<void> _updatePosition({
    required bool announce,
    required bool follow,
  }) async {
    final result = await _location.currentPosition();
    if (!mounted) return;
    switch (result) {
      case PositionFound(:final position):
        final point = LatLng(position.latitude, position.longitude);
        if (follow) _controller.move(point, _zoomForPosition());
        setState(() {
          _userPosition = point;
          // Whatever the strip was asking for has been settled.
          _positionUnavailableReason = null;
        });
      case PositionUnavailable(:final reason):
        // The mark goes with the position: the blue dot and a strip saying we
        // do not know where the user is cannot both be true.
        setState(() {
          _userPosition = null;
          if (announce) _positionUnavailableReason = reason;
        });
    }
  }

  /// Brings the position into view without taking away a closer zoom the user
  /// set by hand — the button says „take me there", not „zoom out".
  double _zoomForPosition() {
    final current = _controller.camera.zoom;
    return current > _positionZoom ? current : _positionZoom;
  }

  /// A tap on the map away from the markers puts the card away. Its refresh,
  /// if still running, is let go: [_cardChurchId] no longer matches. A church
  /// that refresh finds removed still loses its marker, through
  /// [ChurchListLoader.churchesWritten].
  void _closeCard() {
    if (_cardChurchId == null && _card == null) return;
    setState(() {
      _card = null;
      _cardChurchId = null;
    });
  }

  Future<void> _showChurchCard(int churchId) async {
    final query = ChurchCardQuery(churchId);
    // At once, not after the cache read: the pin has to show which church the
    // card that is coming belongs to.
    setState(() => _cardChurchId = churchId);

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ez a templom már nem szerepel a miserend.hu-n.'),
        ),
      );
      return;
    }
    setState(() => _card = refreshed);
  }
}
