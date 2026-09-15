import 'package:flutter/material.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/home/churches/church_list_loader.dart';
import 'package:miserend/home/churches/church_list_view.dart';
import 'package:miserend/widgets/list_status_view.dart';

import 'package:provider/provider.dart';

/// The favorite churches, drawn from the cache at once and refreshed by id in
/// the background (ADR-0003).
class FavoriteChurchesPage extends StatefulWidget {
  const FavoriteChurchesPage({super.key, this.loader});

  /// Injected by tests; the page builds its own otherwise.
  final ChurchListLoader? loader;

  @override
  State<FavoriteChurchesPage> createState() => _FavoriteChurchesPageState();
}

class _FavoriteChurchesPageState extends State<FavoriteChurchesPage>
    with AutomaticKeepAliveClientMixin<FavoriteChurchesPage> {
  late final FavoritesService favoritesService = Provider.of<FavoritesService>(
    context,
    listen: false,
  );
  late final ChurchListLoader _loader =
      widget.loader ??
      ChurchListLoader(onChurchesGone: favoritesService.removeAll);

  ChurchList _list = const ChurchList(
    churches: [],
    failure: null,
    dataAsOf: null,
  );
  bool loading = true;

  /// Incremented on every load so that a slow, outdated read cannot
  /// overwrite the result of a newer one.
  int _loadId = 0;

  late VoidCallback _favoritesListener;

  @override
  void initState() {
    super.initState();
    _favoritesListener = () {
      if (!mounted) return;
      // The first time the favorites arrive the list is loaded and refreshed;
      // after that a change — a church added or removed, one gone from
      // miserend.hu — only needs the cache read again.
      _load(refresh: loading);
    };
    favoritesService.addListener(_favoritesListener);
    _load(refresh: true);
  }

  @override
  void dispose() {
    favoritesService.removeListener(_favoritesListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      color: Colors.black12,
      child:
          loading
              ? const LoadingView(message: 'Kedvencek betöltése...')
              : ChurchListView(
                list: _list,
                emptyMessage: 'Még nincsenek kedvenc templomaid.',
                onRefresh: () => _load(refresh: true),
              ),
    );
  }

  Future<void> _load({required bool refresh}) async {
    if (!favoritesService.loaded) {
      // The favorites are still being read; the service notifies us when
      // they arrive and this method runs again.
      return;
    }
    final loadId = ++_loadId;
    bool current() => mounted && loadId == _loadId;

    final query = FavoritesQuery(
      favoritesService.favorites.map((e) => e.churchId).toList(),
    );
    final cached = await _loader.load(query);
    if (!current()) return;
    setState(() {
      // A banner already up stays until a refresh succeeds.
      _list = ChurchList(
        churches: cached.churches,
        failure: _list.failure,
        dataAsOf: cached.dataAsOf,
      );
      loading = false;
    });

    if (!refresh || query.ids.isEmpty) return;
    final refreshed = await _loader.refresh(query, cached.churches);
    if (!current()) return;
    setState(() => _list = refreshed);
  }

  @override
  bool get wantKeepAlive => true;
}
