import 'package:flutter/foundation.dart';
import 'package:miserend/database/favorite.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/database/local_database.dart';

/// Favorites held in memory, so no test writes the device's database.
class FakeFavoritesService extends ChangeNotifier implements FavoritesService {
  FakeFavoritesService(List<int> ids, {this.loaded = true})
    : favorites = [for (final id in ids) Favorite(churchId: id)];

  @override
  List<Favorite> favorites;

  @override
  bool loaded;

  @override
  late LocalDatabase localDatabase;

  void finishLoading() {
    loaded = true;
    notifyListeners();
  }

  @override
  Future<void> toggle(int churchId) async {
    if (isFavorite(churchId)) {
      favorites = favorites.where((f) => f.churchId != churchId).toList();
    } else {
      favorites = [...favorites, Favorite(churchId: churchId)];
    }
    notifyListeners();
  }

  @override
  Future<void> removeAll(List<int> churchIds) async {
    favorites =
        favorites.where((f) => !churchIds.contains(f.churchId)).toList();
    notifyListeners();
  }

  @override
  bool isFavorite(int churchId) => favorites.any((f) => f.churchId == churchId);
}
