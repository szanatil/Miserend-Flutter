import 'package:flutter/material.dart';
import 'package:miserend/database/church_with_masses.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/database/miserend_database.dart';
import 'package:miserend/home/churches/church_list_item.dart';
import 'package:miserend/widgets/list_status_view.dart';

import 'package:provider/provider.dart';

class FavoriteChurchesPage extends StatefulWidget {
  const FavoriteChurchesPage({super.key});

  @override
  State<FavoriteChurchesPage> createState() => _FavoriteChurchesPageState();
}

class _FavoriteChurchesPageState extends State<FavoriteChurchesPage>
    with AutomaticKeepAliveClientMixin<FavoriteChurchesPage> {

  List<ChurchWithMasses> churches = <ChurchWithMasses>[];
  bool loading = true;

  /// Incremented on every load so that a slow, outdated query cannot
  /// overwrite the result of a newer one.
  int _loadId = 0;

  late FavoritesService favoritesService;
  late VoidCallback _favoritesListener;

  @override
  void initState() {
    super.initState();
    favoritesService = Provider.of<FavoritesService>(context, listen: false);
    _favoritesListener = () {
      if (mounted) {
        loadChurches();
      }
    };
    favoritesService.addListener(_favoritesListener);
    loadChurches();
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
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return const LoadingView(message: 'Kedvencek betöltése...');
    }

    if (churches.isEmpty) {
      return const MessageView(message: 'Még nincsenek kedvenc templomaid.');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: churches.length,
      itemBuilder: (BuildContext context, int index) {
        return ChurchListItem(churchWithMasses: churches[index]);
      },
    );
  }

  Future<void> loadChurches() async {
    // The spinner is only shown for the first load; later refreshes (a
    // church added or removed) swap the list in without flashing.
    final int loadId = ++_loadId;

    if (!favoritesService.loaded) {
      // The favorites are still being read; the service notifies us when
      // they arrive and this method runs again.
      return;
    }

    List<ChurchWithMasses> list = <ChurchWithMasses>[];
    try {
      final ids =
          favoritesService.favorites.map((e) => e.churchId).toList();
      if (ids.isNotEmpty) {
        MiserendDatabase db = await MiserendDatabase.create();
        list = await db.getChurches(ids);
      }
    } catch (_) {
      list = <ChurchWithMasses>[];
    }

    if (!mounted || loadId != _loadId) {
      return;
    }
    setState(() {
      churches = list;
      loading = false;
    });
  }

  @override
  bool get wantKeepAlive => true;
}
