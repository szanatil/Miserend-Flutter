import 'dart:async';

import 'package:flutter/material.dart';
import 'package:miserend/api/nearby_masses_item.dart';
import 'package:miserend/church_details/church_details_page.dart';
import 'package:miserend/church_details/church_schedule_loader.dart';
import 'package:miserend/database/church.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/home/masses/mass_card.dart';
import 'package:miserend/home/masses/nearest_masses.dart';
import 'package:miserend/home/masses/nearest_masses_loader.dart';
import 'package:miserend/location_provider.dart';
import 'package:miserend/widgets/list_status_view.dart';
import 'package:miserend/widgets/position_unavailable_view.dart';
import 'package:provider/provider.dart';

/// The Misék tab: the nearest masses, live from the API.
///
/// The list follows the clock and the user's position rather than being loaded
/// once: it fetches again when it is shown again (tab switch, app back in the
/// foreground), on pull-to-refresh, and after midnight; in between, it is
/// re-selected from the last response on every whole minute, so a mass that
/// stops being reachable drops off by itself, and the time until start changes
/// together with the phone's clock.
class NearMassesPage extends StatefulWidget {
  const NearMassesPage({
    super.key,
    this.isActive = true,
    this.loader,
    this.clock = DateTime.now,
    this.detailsLoader,
    this.location,
  });

  /// Whether the tab is the one on screen. The home screen keeps every opened
  /// tab alive in an IndexedStack, so the page cannot tell by itself.
  final bool isActive;

  /// Injected by tests; the page builds its own otherwise.
  final NearestMassesLoader? loader;

  /// Injected by tests, which need to move the time forward.
  final DateTime Function() clock;

  /// Handed to the details page a row opens; injected by tests.
  final ChurchScheduleLoader? detailsLoader;

  /// Opens the settings pages when there is no position; injected by tests.
  final LocationProvider? location;

  @override
  State<NearMassesPage> createState() => _NearMassesPageState();
}

class _NearMassesPageState extends State<NearMassesPage>
    with WidgetsBindingObserver {
  static const Duration _reselectEvery = Duration(minutes: 1);

  /// How long until the clock reaches the next whole minute: the time until
  /// start drops the seconds (spec 0008, „Ticker igazítása egész percekhez"),
  /// so a tick at any other second would show it up to a minute late.
  static Duration _untilNextMinute(DateTime now) =>
      _reselectEvery -
      Duration(
        seconds: now.second,
        milliseconds: now.millisecond,
        microseconds: now.microsecond,
      );

  late final LocationProvider _location = widget.location ?? LocationProvider();
  late final NearestMassesLoader _loader =
      widget.loader ??
      NearestMassesLoader(
        location: _location,
        onChurchesGone:
            Provider.of<FavoritesService>(context, listen: false).removeAll,
      );

  /// The whole last response, not the ten rows drawn from it: when a mass
  /// expires, its place goes to the church's next mass or to the next nearest
  /// church, and both are only in the full response.
  List<NearbyMassesItem> _items = const [];

  /// The details of the masses listed when a response arrived, kept across
  /// fetches so that a refetch does not blink them off the cards; they are
  /// matched by church and start, so an older one never lands on another
  /// mass. A church that only comes onto the list on a later re-selection
  /// goes without them until the next fetch: re-selection makes no network
  /// call.
  MassDetails _details = const MassDetails();
  PositionUnavailableReason? _noPosition;
  bool _apiFailed = false;
  bool _loaded = false;

  /// When the latest fetch started. Its upper bound is the following
  /// midnight, so once the day changes the response is out of date.
  DateTime? _fetchedAt;

  /// Bumped per fetch so that a slow answer cannot overwrite a newer one.
  int _requestId = 0;

  Timer? _ticker;
  bool _inForeground = true;

  /// Set when the app actually left the screen, so that the brief
  /// inactive/resumed flicker of a system dialog — the location permission
  /// prompt among them — does not count as coming back.
  bool _wasInBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.isActive) {
      _fetch();
      _startTicker();
    }
  }

  @override
  void didUpdateWidget(NearMassesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _fetch();
      _startTicker();
    } else if (!widget.isActive && oldWidget.isActive) {
      _stopTicker();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _inForeground = true;
        if (_wasInBackground && widget.isActive) {
          _fetch();
          _startTicker();
        }
        _wasInBackground = false;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _inForeground = false;
        _wasInBackground = true;
        _stopTicker();
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTicker();
    super.dispose();
  }

  void _startTicker() {
    if (!_inForeground) return;
    _ticker?.cancel();
    _scheduleTick();
  }

  /// Each tick waits for the next whole minute on the clock afresh, rather
  /// than repeating a fixed period, so that a timer running late or a clock
  /// set right does not leave the ticks off the minute.
  void _scheduleTick() {
    _ticker = Timer(_untilNextMinute(widget.clock()), () {
      _scheduleTick();
      _onTick();
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _onTick() {
    // Another page pushed over the tab (a search result, say) hides the list
    // just as well as a tab switch does.
    if (ModalRoute.of(context)?.isCurrent == false) return;
    final fetchedAt = _fetchedAt;
    if (fetchedAt != null && !_isSameDay(fetchedAt, widget.clock())) {
      _fetch();
    } else {
      // No network: the rule runs again over the same response in build.
      setState(() {});
    }
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _fetch() async {
    final requestId = ++_requestId;
    final now = widget.clock();
    _fetchedAt = now;

    List<NearbyMassesItem> items = const [];
    PositionUnavailableReason? noPosition;
    var apiFailed = false;
    try {
      items = await _loader.fetch(now);
    } on LocationUnavailable catch (error) {
      noPosition = error.reason;
    } catch (_) {
      apiFailed = true;
    }

    if (!mounted || requestId != _requestId) return;
    setState(() {
      // A failure drops the previous list: it promised masses one can still
      // reach, and there is no telling any more whether it still does.
      _items = items;
      _noPosition = noPosition;
      _apiFailed = apiFailed;
      _loaded = true;
    });
    unawaited(_fetchDetails(selectNearestMasses(items, now), requestId));
  }

  /// Not awaited by [_fetch], so that the list is drawn without waiting for
  /// the details (spec 0011, „Forrás").
  Future<void> _fetchDetails(
    List<NearbyMassesItem> masses,
    int requestId,
  ) async {
    if (masses.isEmpty) return;
    final details = await _loader.fetchMassDetails(masses, widget.clock());
    if (!mounted || requestId != _requestId) return;
    setState(() => _details = _details.merged(details));
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const _Ground(
        child: LoadingView(message: 'Legközelebbi misék betöltése…'),
      );
    }
    return RefreshIndicator(onRefresh: _fetch, child: _content());
  }

  Widget _content() {
    final noPosition = _noPosition;
    if (noPosition != null) {
      return _Ground(
        child: PullableFill(
          child: PositionUnavailableView(
            reason: noPosition,
            purpose: 'A legközelebbi misékhez',
            location: _location,
            onRetry: _fetch,
          ),
        ),
      );
    }
    if (_apiFailed) {
      return const _Ground(
        child: PullableFill(
          child: MessageView(
            message:
                'Nem sikerült betölteni a miséket. '
                'Ellenőrizd az internetkapcsolatot.',
          ),
        ),
      );
    }

    final now = widget.clock();
    final masses = selectNearestMasses(_items, now);
    if (masses.isEmpty) {
      return const _Ground(
        child: PullableFill(
          child: MessageView(message: 'A közelben ma már nincs elérhető mise.'),
        ),
      );
    }

    return _Ground(
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(8),
        itemCount: masses.length,
        itemBuilder: (BuildContext context, int index) {
          final mass = masses[index];
          return MassCard(
            mass: mass,
            detail: _details.of(mass),
            now: now,
            thumbnailUrl: _loader.thumbnailUrl(mass.churchId),
            onTap: () => _openChurch(mass),
          );
        },
      ),
    );
  }

  /// The details page loads everything by id; the item only has to seed the
  /// name and the map until then.
  Future<void> _openChurch(NearbyMassesItem mass) async {
    final church = Church(
      id: mass.churchId,
      name: mass.churchName,
      commonName: null,
      isGreek: null,
      lat: mass.lat,
      lon: mass.lon,
      address: null,
      city: mass.city,
      country: null,
      county: null,
      street: null,
      gettingThere: null,
      imageUrl: null,
    );
    _stopTicker();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                ChurchDetailsPage(church: church, loader: widget.detailsLoader),
      ),
    );
    if (!mounted || !widget.isActive || !_inForeground) return;
    // Catch up on the minutes spent on the details page before ticking on.
    _onTick();
    _startTicker();
  }
}

/// The grey the Templomok tab draws its lists and its loading and message
/// states on, so that the two tabs look like one app.
class _Ground extends StatelessWidget {
  const _Ground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Container(color: Colors.black12, child: child);
}
