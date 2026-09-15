import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/api/api_result.dart';
import 'package:miserend/database/cache/church_list_entry.dart';
import 'package:miserend/database/favorite.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/database/local_database.dart';
import 'package:miserend/home/churches/church_list_loader.dart';
import 'package:miserend/home/churches/favorite_churches.dart';
import 'package:miserend/widgets/offline_notice.dart';
import 'package:provider/provider.dart';

import 'fake_church_list_loader.dart';

ChurchListEntry _entry(int id, String name) => ChurchListEntry(
      id: id,
      name: name,
      commonName: null,
      city: 'Budapest',
      lat: 47.5,
      lon: 19.04,
      photo: null,
      masses: const [],
    );

/// Favorites held in memory, so no test writes the device's database.
class _FakeFavorites extends ChangeNotifier implements FavoritesService {
  _FakeFavorites(List<int> ids, {this.loaded = true})
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
  bool isFavorite(int churchId) =>
      favorites.any((f) => f.churchId == churchId);
}

void main() {
  Future<void> pumpPage(WidgetTester tester, ChurchListLoader loader,
      FavoritesService favorites) async {
    await tester.pumpWidget(ChangeNotifierProvider<FavoritesService>.value(
      value: favorites,
      child: MaterialApp(
        home: Scaffold(body: FavoriteChurchesPage(loader: loader)),
      ),
    ));
    await tester.pump();
    await tester.pump();
  }

  Future<void> pullToRefresh(WidgetTester tester) async {
    await tester.fling(
        find.byType(Scrollable).first, const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('shows the loading caption until the favorites are known',
      (tester) async {
    final favorites = _FakeFavorites(const [1], loaded: false);
    final loader = FakeChurchListLoader([
      [_entry(1, 'Kedvenc')]
    ]);

    await pumpPage(tester, loader, favorites);
    expect(find.text('Kedvencek betöltése...'), findsOneWidget);
    expect(loader.reads, 0);

    favorites.finishLoading();
    await tester.pump();
    await tester.pump();
    expect(find.text('Kedvenc'), findsOneWidget);
  });

  testWidgets('with no favorites, says so and asks nothing', (tester) async {
    final loader = FakeChurchListLoader([<ChurchListEntry>[]]);

    await pumpPage(tester, loader, _FakeFavorites(const []));

    expect(find.text('Még nincsenek kedvenc templomaid.'), findsOneWidget);
    expect(loader.refreshes, 0);
  });

  testWidgets('lists the favorites from the cache, then refreshes them by id',
      (tester) async {
    final loader = FakeChurchListLoader([
      [_entry(1, 'Első'), _entry(2, 'Második')]
    ], refreshed: [
      Completer<ChurchList>()
    ]);

    await pumpPage(tester, loader, _FakeFavorites(const [1, 2]));

    expect(find.text('Első'), findsOneWidget);
    expect(find.text('Második'), findsOneWidget);
    expect((loader.queries.single as FavoritesQuery).ids, [1, 2]);
    expect(loader.refreshes, 1);
    expect(find.byType(OfflineBanner), findsNothing);
  });

  testWidgets('a favorite removed from miserend.hu disappears after the '
      'refresh', (tester) async {
    final loader = FakeChurchListLoader([
      [_entry(1, 'Megmaradt'), _entry(2, 'Megszűnt')]
    ], refreshed: [
      listOf([_entry(1, 'Megmaradt')])
    ]);

    await pumpPage(tester, loader, _FakeFavorites(const [1, 2]));

    expect(find.text('Megmaradt'), findsOneWidget);
    expect(find.text('Megszűnt'), findsNothing);
  });

  testWidgets('no connection and server error put up the banner',
      (tester) async {
    final loader = FakeChurchListLoader([
      [_entry(1, 'Kedvenc')]
    ], refreshed: [
      listOf(const [], failure: ApiFailure.serverError)
    ]);

    await pumpPage(tester, loader, _FakeFavorites(const [1]));

    expect(find.text('Kedvenc'), findsOneWidget);
    expect(find.byType(OfflineBanner), findsOneWidget);
    expect(find.text('A miserend.hu nem elérhető, tárolt adatok'),
        findsOneWidget);
  });

  testWidgets('pulling down refreshes again', (tester) async {
    final loader = FakeChurchListLoader([
      [_entry(1, 'Kedvenc')]
    ], refreshed: [
      listOf(const [], failure: ApiFailure.noConnection),
      listOf([_entry(1, 'Kedvenc')]),
    ]);
    await pumpPage(tester, loader, _FakeFavorites(const [1]));
    expect(find.byType(OfflineBanner), findsOneWidget);

    await pullToRefresh(tester);

    expect(loader.refreshes, 2);
    expect(find.byType(OfflineBanner), findsNothing);
  });

  testWidgets('a favorite added elsewhere is read from the cache, without '
      'another call', (tester) async {
    final favorites = _FakeFavorites(const [1]);
    final loader = FakeChurchListLoader([
      [_entry(1, 'Első')],
      [_entry(1, 'Első'), _entry(2, 'Új kedvenc')],
    ]);
    await pumpPage(tester, loader, favorites);

    await favorites.toggle(2);
    await tester.pump();
    await tester.pump();

    expect(find.text('Új kedvenc'), findsOneWidget);
    expect(loader.refreshes, 1);
  });
}
