import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/api/api_result.dart';
import 'package:miserend/database/cache/church_list_entry.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/home/churches/church_list_loader.dart';
import 'package:miserend/home/churches/search_results.dart';
import 'package:miserend/widgets/distance_chip.dart';
import 'package:miserend/widgets/offline_notice.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fake_church_list_loader.dart';

ChurchListEntry _entry(int id, String name) => ChurchListEntry(
  id: id,
  name: name,
  commonName: null,
  city: 'Szeged',
  lat: 46.25,
  lon: 20.14,
  photo: null,
  masses: const [],
);

void main() {
  // The rows read favorites, which live in a local database. Built once, in
  // the real async zone: see church_details_page_test.
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late FavoritesService favorites;

  setUpAll(() async {
    favorites = FavoritesService();
    for (var i = 0; i < 400 && !favorites.loaded; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  });

  Future<void> pumpPage(
    WidgetTester tester,
    ChurchListLoader loader, {
    SearchParams? params,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<FavoritesService>.value(
        value: favorites,
        child: MaterialApp(
          home: SearchResultsPage(
            searchParams:
                params ?? SearchParams.fromSearchTerm('Boldogasszony'),
            loader: loader,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> pullToRefresh(WidgetTester tester) async {
    await tester.fling(
      find.byType(Scrollable).first,
      const Offset(0, 400),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('titles the page with the search term', (tester) async {
    await pumpPage(tester, FakeChurchListLoader([<ChurchListEntry>[]]));

    expect(find.text('Boldogasszony'), findsOneWidget);
  });

  testWidgets('shows the loading caption while the cache is searched', (
    tester,
  ) async {
    await pumpPage(
      tester,
      FakeChurchListLoader([Completer<List<ChurchListEntry>>()]),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('says so when nothing is found', (tester) async {
    await pumpPage(tester, FakeChurchListLoader([<ChurchListEntry>[]]));

    expect(find.text('Nincs találat'), findsOneWidget);
  });

  testWidgets('lists what the cache found, then refreshes it', (tester) async {
    final loader = FakeChurchListLoader(
      [
        [_entry(1155, 'Havas Boldogasszony templom')],
      ],
      refreshed: [Completer<ChurchList>()],
    );

    await pumpPage(tester, loader);

    expect(find.text('Havas Boldogasszony templom'), findsOneWidget);
    expect(loader.refreshes, 1);
    expect(find.byType(OfflineBanner), findsNothing);
  });

  testWidgets('shows no distance: the page does not ask for the position', (
    tester,
  ) async {
    await pumpPage(
      tester,
      FakeChurchListLoader([
        [_entry(1155, 'Havas Boldogasszony templom')],
      ]),
    );

    expect(find.text('Havas Boldogasszony templom'), findsOneWidget);
    expect(find.byType(DistanceChip), findsNothing);
  });

  testWidgets('searches a city as a city', (tester) async {
    final loader = FakeChurchListLoader([<ChurchListEntry>[]]);

    await pumpPage(tester, loader, params: SearchParams.fromCity('Szeged'));

    final query = loader.queries.single as SearchQuery;
    expect(query.city, 'Szeged');
    expect(query.term, isNull);
    expect(find.text('Szeged'), findsOneWidget);
  });

  testWidgets('a church found by the API search appears after the refresh', (
    tester,
  ) async {
    await pumpPage(
      tester,
      FakeChurchListLoader(
        [<ChurchListEntry>[]],
        refreshed: [
          listOf([_entry(4242, 'Új Boldogasszony templom')]),
        ],
      ),
    );

    expect(find.text('Új Boldogasszony templom'), findsOneWidget);
    expect(find.text('Nincs találat'), findsNothing);
  });

  testWidgets('a failed refresh puts up the banner over the results', (
    tester,
  ) async {
    await pumpPage(
      tester,
      FakeChurchListLoader(
        [
          [_entry(1155, 'Havas Boldogasszony templom')],
        ],
        refreshed: [listOf(const [], failure: ApiFailure.noConnection)],
      ),
    );

    expect(find.byType(OfflineBanner), findsOneWidget);
    expect(find.text('Havas Boldogasszony templom'), findsOneWidget);
  });

  testWidgets('no banner while a pulled refresh runs; a failure puts it back', (
    tester,
  ) async {
    final retry = Completer<ChurchList>();
    final loader = FakeChurchListLoader(
      [
        [_entry(1155, 'Havas Boldogasszony templom')],
      ],
      refreshed: [listOf(const [], failure: ApiFailure.serverError), retry],
    );
    await pumpPage(tester, loader);
    expect(find.byType(OfflineBanner), findsOneWidget);

    await pullToRefresh(tester);
    expect(find.byType(OfflineBanner), findsNothing);

    retry.complete(
      listOf([
        _entry(1155, 'Havas Boldogasszony templom'),
      ], failure: ApiFailure.serverError),
    );
    await tester.pump();
    expect(find.byType(OfflineBanner), findsOneWidget);
  });

  testWidgets('pulling down refreshes again', (tester) async {
    final loader = FakeChurchListLoader(
      [
        [_entry(1155, 'Havas Boldogasszony templom')],
      ],
      refreshed: [
        listOf(const [], failure: ApiFailure.serverError),
        listOf([_entry(1155, 'Havas Boldogasszony templom')]),
      ],
    );
    await pumpPage(tester, loader);

    await pullToRefresh(tester);

    expect(loader.refreshes, 2);
    expect(find.byType(OfflineBanner), findsNothing);
  });
}
