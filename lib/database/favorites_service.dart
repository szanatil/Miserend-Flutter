import 'package:flutter/cupertino.dart';
import 'package:miserend/database/favorite.dart';
import 'package:miserend/database/local_database.dart';

class FavoritesService extends ChangeNotifier {
  late LocalDatabase localDatabase;

  List<Favorite> favorites = <Favorite>[];

  /// False until the favorites have been read from the local database.
  bool loaded = false;

  FavoritesService() {
    _init();
  }

  Future<void> _init() async {
    localDatabase = await LocalDatabase.create();
    favorites = await localDatabase.getFavorites();
    loaded = true;
    notifyListeners();
  }

  Future<void> toggle(int churchId) async {
    if (isFavorite(churchId)) {
      await localDatabase.removeFavorite(churchId);
    } else {
      await localDatabase.addFavorite(churchId);
    }
    favorites = await localDatabase.getFavorites();
    notifyListeners();
  }

  /// Drops churches miserend.hu no longer has. Silent: the favorites list
  /// shows no "removed" row for them.
  Future<void> removeAll(List<int> churchIds) async {
    final present = churchIds.where(isFavorite).toList();
    if (present.isEmpty) return;
    for (final churchId in present) {
      await localDatabase.removeFavorite(churchId);
    }
    favorites = await localDatabase.getFavorites();
    notifyListeners();
  }

  bool isFavorite(int churchId) =>
      favorites.any((element) => element.churchId == churchId);
}
