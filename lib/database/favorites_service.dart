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
      localDatabase.removeFavorite(churchId);
    } else {
      localDatabase.addFavorite(churchId);
    }
    favorites = await localDatabase.getFavorites();
    notifyListeners();
  }

  bool isFavorite(int churchId) =>
      favorites.any((element) => element.churchId == churchId);
}
