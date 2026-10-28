import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:miserend/database/cache/church_list_entry.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/home/churches/church_card.dart';
import 'package:miserend/home/churches/church_list_loader.dart';
import 'package:miserend/home/map/widgets/missing_churches_banner.dart';
import 'package:miserend/home/map/widgets/position_unavailable_banner.dart';
import 'package:miserend/location_provider.dart';
import 'package:miserend/theme/miserend_theme.dart';
import 'package:miserend/theme/tokens.dart';
import 'package:miserend/widgets/miserend_map.dart';
import 'package:miserend/widgets/stale_data_retry.dart';
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

  /// Between the map's edges and what floats on it, the church card and the
  /// my-position button (KO18).
  static const double _edgeGap = Spacing.l;

  /// The most of the tab the information strip takes. Its sentence runs to
  /// many lines on a narrow phone with large text, and the map it is about
  /// must stay in sight; past this the strip scrolls (DESIGN.md EL2).
  static const double _maxStripShare = 0.5;

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

  /// Whether the markers have been read once: before that an empty area says
  /// nothing.
  bool _markersLoaded = false;

  /// Where the camera was last seen; null until the map is ready.
  MapCamera? _camera;

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
    _loader.bootstrapped.addListener(_rebuild);
    _loader.lastFailure.addListener(_rebuild);
    _loadMarkers();
    // Quietly: a strip the moment the tab opens would answer a question
    // nobody asked. Without a position the map stays on the country.
    _refreshPosition();
  }

  @override
  void dispose() {
    _loader.churchesWritten.removeListener(_loadMarkers);
    _loader.bootstrapped.removeListener(_rebuild);
    _loader.lastFailure.removeListener(_rebuild);
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

  void _rebuild() {
    if (mounted) setState(() {});
  }

  /// No church in view, and the bootstrap import has not run, which may be
  /// why. Offline the map shows the cache either way, and the screens' own
  /// offline notices say so (spec 0015, „Tájékoztatás").
  bool get _mayLackBootstrap {
    final camera = _camera;
    if (camera == null ||
        !_markersLoaded ||
        _loader.bootstrapped.value ||
        _loader.lastFailure.value != null) {
      return false;
    }
    final bounds = camera.visibleBounds;
    return !_markers.any((marker) => bounds.contains(marker.point));
  }

  /// Rebuilds only when the camera's move may have changed what the strip
  /// says, not on every frame of a pan.
  void _onCameraChanged(MapCamera camera) {
    final before = _mayLackBootstrap;
    _camera = camera;
    if (_mayLackBootstrap != before) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final card = _card;
    final ChurchListEntry? entry =
        card == null || card.churches.isEmpty ? null : card.churches.first;
    final noPosition = _positionUnavailableReason;
    return LayoutBuilder(
      builder:
          (context, constraints) => Column(
            children: [
              // Over the map, not on it: what is in view is what the strip is
              // about, and it would hide some of it.
              if (_mayLackBootstrap)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * _maxStripShare,
                  ),
                  child: const SingleChildScrollView(
                    child: MissingChurchesBanner(),
                  ),
                ),
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
                      onCameraChanged: _onCameraChanged,
                    ),
                    // The button stands on the card, so wherever the card's
                    // content puts its top, the button is clear above it. A card
                    // taller than the room — large text, a phone on its side —
                    // scrolls rather than overflow (DESIGN.md EL2, EL5).
                    Positioned.fill(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(
                              top: _edgeGap,
                              right: _edgeGap,
                              bottom: entry == null ? _edgeGap : 0,
                            ),
                            child: FloatingActionButton(
                              // No hero: the Névjegy tab's button lives beside this
                              // one, and two default tags fail a full-screen push
                              // over the tabs.
                              heroTag: null,
                              onPressed: _goToMyPosition,
                              child: const Icon(Icons.my_location_rounded),
                            ),
                          ),
                          if (entry != null)
                            Flexible(
                              child: Padding(
                                padding: const EdgeInsets.all(_edgeGap),
                                child: SingleChildScrollView(
                                  child: _cardWithRetry(entry, card!),
                                ),
                              ),
                            ),
                        ],
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
                  onClose:
                      () => setState(() => _positionUnavailableReason = null),
                ),
            ],
          ),
    );
  }

  /// The card has no **Nincs kapcsolat** strip of its own, only the (i), so
  /// the retry that the strip drives elsewhere hangs off the card itself —
  /// and only while the card is actually marked as stale.
  Widget _cardWithRetry(ChurchListEntry entry, ChurchList card) {
    final child = Theme(
      data: mapCardTheme(Theme.of(context)),
      child: ChurchCard(
        entry: entry,
        // The position as of now: the distance goes and comes with the mark.
        position: _userPosition,
        failure: card.failure,
        dataAsOf: card.dataAsOf,
      ),
    );
    if (card.failure == null) return child;
    return StaleDataRetry(onRetry: _refreshCard, child: child);
  }

  Future<void> _loadMarkers() async {
    final loadId = ++_markersLoadId;
    final locations = await _loader.churchLocations();
    if (!mounted || loadId != _markersLoadId) return;
    setState(() {
      _markersLoaded = true;
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

    await _refreshCard();
  }

  /// Asks the API for the open card again. Not through [_showChurchCard]: that
  /// drops back to the cache first, which would blink the card's (i) off and
  /// on at every retry.
  Future<void> _refreshCard() async {
    final card = _card;
    final churchId = _cardChurchId;
    if (card == null || churchId == null) return;
    final query = ChurchCardQuery(churchId);

    final refreshed = await _loader.refresh(query, card.churches);
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
