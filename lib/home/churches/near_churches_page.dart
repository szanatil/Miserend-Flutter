import 'package:flutter/material.dart';
import 'package:miserend/database/cache/church_list_entry.dart';
import 'package:miserend/home/churches/church_card.dart';
import 'package:miserend/home/churches/church_list_loader.dart';
import 'package:miserend/location_provider.dart';
import 'package:miserend/widgets/list_status_view.dart';
import 'package:miserend/widgets/position_unavailable_view.dart';

/// Every church, nearest to the user's position first, read from the cache.
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
  late final LocationProvider _location =
      widget.location ?? LocationProvider();

  List<ChurchListEntry> _churches = const [];
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
      child: _loaded
          ? RefreshIndicator(onRefresh: _load, child: _content())
          : const LoadingView(message: 'Közeli templomok betöltése...'),
    );
  }

  Widget _content() {
    final noPosition = _noPosition;
    if (noPosition != null) {
      return PullableFill(
        child: PositionUnavailableView(
          reason: noPosition,
          purpose: 'A közeli templomokhoz',
          location: _location,
          onRetry: _load,
        ),
      );
    }

    if (_churches.isEmpty) {
      return const PullableFill(
          child: MessageView(message: 'Nem találhatóak közeli templomok.'));
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(8),
      itemCount: _churches.length,
      itemBuilder: (BuildContext context, int index) {
        return ChurchCard(entry: _churches[index]);
      },
    );
  }

  Future<void> _load() async {
    final loadId = ++_loadId;

    var churches = const <ChurchListEntry>[];
    PositionUnavailableReason? noPosition;
    switch (await _location.currentPosition()) {
      case PositionFound(:final position):
        churches =
            await _loader.nearChurches(position.latitude, position.longitude);
      case PositionUnavailable(:final reason):
        noPosition = reason;
    }

    if (!mounted || loadId != _loadId) return;
    setState(() {
      _churches = churches;
      _noPosition = noPosition;
      _loaded = true;
    });
  }

  @override
  bool get wantKeepAlive => true;
}
