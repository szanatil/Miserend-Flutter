import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:miserend/home/churches/church_list_loader.dart';
import 'package:miserend/home/churches/church_list_view.dart';
import 'package:miserend/location_provider.dart';
import 'package:miserend/widgets/list_status_view.dart';
import 'package:miserend/widgets/position_unavailable_view.dart';

/// Every church, nearest to the user's position first. Drawn from the cache
/// at once, then again once the NearBy answer has been written through to it
/// (ADR-0003).
class NearChurchesPage extends StatefulWidget {
  const NearChurchesPage({super.key, this.loader, this.location});

  /// Injected by tests; the page builds its own otherwise.
  final ChurchListLoader? loader;
  final LocationProvider? location;

  @override
  State<NearChurchesPage> createState() => _NearChurchesPageState();
}

class _NearChurchesPageState extends State<NearChurchesPage>
    with
        AutomaticKeepAliveClientMixin<NearChurchesPage>,
        WidgetsBindingObserver {
  late final ChurchListLoader _loader = widget.loader ?? ChurchListLoader();
  late final LocationProvider _location = widget.location ?? LocationProvider();

  ChurchList _list = const ChurchList(
    churches: [],
    failure: null,
    dataAsOf: null,
  );
  PositionUnavailableReason? _noPosition;
  bool _loaded = false;

  /// Bumped per load so that a slow answer cannot overwrite a newer one.
  int _loadId = 0;

  /// Set when the app actually left the screen, so that the brief
  /// inactive/resumed flicker of the permission prompt does not count as
  /// coming back.
  bool _wasInBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Someone sent to the settings to allow the position comes back expecting
  /// the list.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_wasInBackground && _noPosition != null) _load();
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
    super.build(context);
    return Container(
      color: Colors.black12,
      child:
          _loaded
              ? _content()
              : const LoadingView(message: 'Közeli templomok betöltése...'),
    );
  }

  Widget _content() {
    final noPosition = _noPosition;
    if (noPosition != null) {
      return RefreshIndicator(
        onRefresh: _load,
        child: PullableFill(
          child: PositionUnavailableView(
            reason: noPosition,
            purpose: 'A közeli templomokhoz',
            location: _location,
            onRetry: _load,
          ),
        ),
      );
    }

    return ChurchListView(
      list: _list,
      emptyMessage: 'Nem találhatóak közeli templomok.',
      onRefresh: _load,
    );
  }

  /// Asks for the position, draws the cached list, then refreshes it in the
  /// background. Pull-to-refresh waits for the whole of it.
  Future<void> _load() async {
    final loadId = ++_loadId;
    bool current() => mounted && loadId == _loadId;

    final Position position;
    switch (await _location.currentPosition()) {
      case PositionFound(position: final found):
        position = found;
      case PositionUnavailable(:final reason):
        if (!current()) return;
        setState(() {
          _noPosition = reason;
          _loaded = true;
        });
        return;
    }

    final query = NearChurchesQuery(
      lat: position.latitude,
      lon: position.longitude,
    );
    final cached = await _loader.load(query);
    if (!current()) return;
    setState(() {
      // A banner already up stays until a refresh succeeds; the first load
      // has none, since nothing has failed yet.
      _list = ChurchList(
        churches: cached.churches,
        failure: _list.failure,
        dataAsOf: cached.dataAsOf,
      );
      _noPosition = null;
      _loaded = true;
    });

    final refreshed = await _loader.refresh(query, cached.churches);
    if (!current()) return;
    setState(() => _list = refreshed);
  }

  @override
  bool get wantKeepAlive => true;
}
