import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:miserend/api/api_result.dart';
import 'package:miserend/database/cache/cached_mass.dart';
import 'package:miserend/database/cache/church_list_entry.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/home/churches/church_list_loader.dart';
import 'package:miserend/home/churches/near_churches_page.dart';
import 'package:miserend/location_provider.dart';
import 'package:miserend/widgets/offline_notice.dart';
import 'package:miserend/widgets/time_chip.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Position _position() => Position(
      latitude: 47.4979,
      longitude: 19.0402,
      timestamp: DateTime(2026, 9, 15, 12, 0),
      accuracy: 10,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

CachedMass _row(int hour, String info, MassSource source) => CachedMass(
      id: null,
      apiMassId: null,
      churchId: 1,
      time: DateTime(2026, 9, 15, hour, 0),
      info: info,
      source: source,
    );

ChurchListEntry _entry(String name, {List<CachedMass> masses = const []}) =>
    ChurchListEntry(
      id: name.hashCode,
      name: name,
      commonName: null,
      city: 'Budapest',
      lat: 47.5,
      lon: 19.04,
      photo: null,
      masses: masses,
    );

/// Each call takes the next answer; the last one repeats.
class _FakeLocation extends LocationProvider {
  _FakeLocation(List<PositionResult> answers) : _answers = Queue.of(answers);

  final Queue<PositionResult> _answers;
  int calls = 0;
  int appSettingsOpened = 0;
  int locationSettingsOpened = 0;

  @override
  Future<PositionResult> currentPosition() async {
    calls++;
    return _answers.length > 1 ? _answers.removeFirst() : _answers.first;
  }

  @override
  Future<void> openAppSettings() async => appSettingsOpened++;

  @override
  Future<void> openLocationSettings() async => locationSettingsOpened++;
}

/// Answers [load] with the cache's rows and each [refresh] with the next
/// refresh answer: a [ChurchList], or a completer to wait on. With no refresh
/// answers, a refresh succeeds and changes nothing.
class _FakeLoader extends ChurchListLoader {
  _FakeLoader(List<Object> cached, {List<Object> refreshed = const []})
      : _cached = Queue.of(cached),
        _refreshed = Queue.of(refreshed);

  final Queue<Object> _cached;
  final Queue<Object> _refreshed;
  int reads = 0;
  int refreshes = 0;
  final List<ChurchListQuery> queries = [];

  static Object _next(Queue<Object> answers) =>
      answers.length > 1 ? answers.removeFirst() : answers.first;

  @override
  Future<ChurchList> load(ChurchListQuery query) async {
    reads++;
    queries.add(query);
    final answer = _next(_cached);
    if (answer is Completer<List<ChurchListEntry>>) {
      return _listOf(await answer.future);
    }
    return _listOf(answer as List<ChurchListEntry>);
  }

  @override
  Future<ChurchList> refresh(
      ChurchListQuery query, List<ChurchListEntry> shown) async {
    refreshes++;
    if (_refreshed.isEmpty) return _listOf(shown);
    final answer = _next(_refreshed);
    if (answer is Completer<ChurchList>) return answer.future;
    final list = answer as ChurchList;
    // A failed refresh keeps what is shown, as the real loader does.
    return list.failure == null
        ? list
        : ChurchList(
            churches: shown, failure: list.failure, dataAsOf: list.dataAsOf);
  }
}

ChurchList _listOf(List<ChurchListEntry> churches,
        {ApiFailure? failure, DateTime? dataAsOf}) =>
    ChurchList(churches: churches, failure: failure, dataAsOf: dataAsOf);

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

  Future<void> pumpPage(WidgetTester tester, ChurchListLoader loader,
      LocationProvider location) async {
    await tester.pumpWidget(ChangeNotifierProvider<FavoritesService>.value(
      value: favorites,
      child: MaterialApp(
        home: Scaffold(
          body: NearChurchesPage(loader: loader, location: location),
        ),
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

  final found = PositionFound(_position());

  group('states', () {
    testWidgets('shows the loading caption while the cache is read',
        (tester) async {
      await pumpPage(tester, _FakeLoader([Completer<List<ChurchListEntry>>()]),
          _FakeLocation([found]));

      expect(find.text('Közeli templomok betöltése...'), findsOneWidget);
    });

    testWidgets('says so when there is no church nearby', (tester) async {
      await pumpPage(
          tester, _FakeLoader([<ChurchListEntry>[]]), _FakeLocation([found]));

      expect(find.text('Nem találhatóak közeli templomok.'), findsOneWidget);
    });

    testWidgets('lists the churches in the order the cache gives them',
        (tester) async {
      await pumpPage(
          tester,
          _FakeLoader([
            [_entry('Közelebbi'), _entry('Távolabbi')]
          ]),
          _FakeLocation([found]));

      expect(find.text('Közelebbi'), findsOneWidget);
      expect(find.text('Távolabbi'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Közelebbi')).dy,
          lessThan(tester.getTopLeft(find.text('Távolabbi')).dy));
    });

    testWidgets('a row shows masses only, not confession or adoration',
        (tester) async {
      await pumpPage(
          tester,
          _FakeLoader([
            [
              _entry('Templom', masses: [
                _row(7, 'Szentmise', MassSource.nearbyMasses),
                _row(9, 'Gyóntatás', MassSource.nearbyMasses),
                _row(18, 'gitáros', MassSource.bootstrap),
              ])
            ]
          ]),
          _FakeLocation([found]));

      expect(find.byType(TimeChip), findsNWidgets(2));
      expect(find.text('07:00'), findsOneWidget);
      expect(find.text('09:00'), findsNothing);
      expect(find.text('18:00'), findsOneWidget);
    });
  });

  group('position unavailable', () {
    const cases = {
      PositionUnavailableReason.permissionDenied: (
        'A közeli templomokhoz engedélyezd a helyadatot.',
        'Engedélyezés'
      ),
      PositionUnavailableReason.permissionDeniedForever: (
        'A közeli templomokhoz engedélyezd a helyadatot a telefon '
            'beállításaiban.',
        'Beállítások megnyitása'
      ),
      PositionUnavailableReason.serviceDisabled: (
        'A közeli templomokhoz kapcsold be a helymeghatározást.',
        'Beállítások megnyitása'
      ),
      PositionUnavailableReason.noFreshFix: (
        'Nem sikerült meghatározni a helyzetedet.',
        null
      ),
    };

    for (final MapEntry(key: reason, value: (text, button)) in cases.entries) {
      testWidgets('${reason.name}: the reason and its way out',
          (tester) async {
        final loader = _FakeLoader([<ChurchListEntry>[]]);
        await pumpPage(
            tester, loader, _FakeLocation([PositionUnavailable(reason)]));

        expect(find.text(text), findsOneWidget);
        if (button == null) {
          expect(find.byType(FilledButton), findsNothing);
        } else {
          expect(find.widgetWithText(FilledButton, button), findsOneWidget);
        }
        expect(loader.reads, 0, reason: 'no position, no list');
      });
    }

    testWidgets('allowing the permission lists the churches', (tester) async {
      final location = _FakeLocation([
        const PositionUnavailable(PositionUnavailableReason.permissionDenied),
        found,
      ]);
      await pumpPage(tester, _FakeLoader([
        [_entry('Templom')]
      ]), location);

      await tester.tap(find.widgetWithText(FilledButton, 'Engedélyezés'));
      await tester.pump();
      await tester.pump();

      expect(location.calls, 2);
      expect(find.text('Templom'), findsOneWidget);
    });

    testWidgets('denied for good opens the app settings', (tester) async {
      final location = _FakeLocation([
        const PositionUnavailable(
            PositionUnavailableReason.permissionDeniedForever)
      ]);
      await pumpPage(tester, _FakeLoader([<ChurchListEntry>[]]), location);

      await tester
          .tap(find.widgetWithText(FilledButton, 'Beállítások megnyitása'));

      expect(location.appSettingsOpened, 1);
      expect(location.locationSettingsOpened, 0);
    });

    testWidgets('location services off opens the location settings',
        (tester) async {
      final location = _FakeLocation([
        const PositionUnavailable(PositionUnavailableReason.serviceDisabled)
      ]);
      await pumpPage(tester, _FakeLoader([<ChurchListEntry>[]]), location);

      await tester
          .tap(find.widgetWithText(FilledButton, 'Beállítások megnyitása'));

      expect(location.locationSettingsOpened, 1);
      expect(location.appSettingsOpened, 0);
    });

    testWidgets('coming back from the settings tries the position again',
        (tester) async {
      final location = _FakeLocation([
        const PositionUnavailable(PositionUnavailableReason.serviceDisabled),
        found,
      ]);
      await pumpPage(tester, _FakeLoader([
        [_entry('Templom')]
      ]), location);

      final binding = tester.binding;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(location.calls, 2);
      expect(find.text('Templom'), findsOneWidget);
    });
  });

  group('pull to refresh', () {
    testWidgets('asks for the position again and reads the cache again',
        (tester) async {
      final location = _FakeLocation([found]);
      final loader = _FakeLoader([
        [_entry('Régi')],
        [_entry('Új')],
      ]);
      await pumpPage(tester, loader, location);

      await pullToRefresh(tester);

      expect(location.calls, 2);
      expect(loader.reads, 2);
      expect(find.text('Új'), findsOneWidget);
    });

    testWidgets('works from the position message too', (tester) async {
      final location = _FakeLocation([
        const PositionUnavailable(PositionUnavailableReason.noFreshFix),
        found,
      ]);
      await pumpPage(tester, _FakeLoader([
        [_entry('Templom')]
      ]), location);

      await pullToRefresh(tester);

      expect(find.text('Templom'), findsOneWidget);
    });
  });

  group('background refresh', () {
    testWidgets('asks around the position the list was read for',
        (tester) async {
      final loader = _FakeLoader([
        [_entry('Templom')]
      ]);
      await pumpPage(tester, loader, _FakeLocation([found]));

      final query = loader.queries.single as NearChurchesQuery;
      expect((query.lat, query.lon), (47.4979, 19.0402));
      expect(loader.refreshes, 1);
    });

    testWidgets('shows the cached list and no mark while the call runs',
        (tester) async {
      await pumpPage(
          tester,
          _FakeLoader([
            [_entry('Tárolt')]
          ], refreshed: [
            Completer<ChurchList>()
          ]),
          _FakeLocation([found]));

      expect(find.text('Tárolt'), findsOneWidget);
      expect(find.byType(OfflineBanner), findsNothing);
    });

    testWidgets('a new church from the answer appears in the list',
        (tester) async {
      await pumpPage(
          tester,
          _FakeLoader([
            [_entry('Tárolt')]
          ], refreshed: [
            _listOf([_entry('Tárolt'), _entry('Új templom')])
          ]),
          _FakeLocation([found]));

      expect(find.text('Új templom'), findsOneWidget);
      expect(find.byType(OfflineBanner), findsNothing);
    });

    testWidgets('no connection puts the banner above the list, untinted',
        (tester) async {
      await pumpPage(
          tester,
          _FakeLoader([
            [_entry('Tárolt')]
          ], refreshed: [
            _listOf(const [], failure: ApiFailure.noConnection)
          ]),
          _FakeLocation([found]));

      expect(find.text('Tárolt'), findsOneWidget);
      expect(find.byType(OfflineBanner), findsOneWidget);
      expect(find.byType(OfflineInfoButton), findsOneWidget);
      expect(tester.getTopLeft(find.byType(OfflineBanner)).dy,
          lessThan(tester.getTopLeft(find.text('Tárolt')).dy));
      expect(
          tester
              .widget<Material>(find
                  .descendant(
                      of: find.byType(OfflineBanner),
                      matching: find.byType(Material))
                  .first)
              .color,
          isNot(OfflineNotice.serverErrorTint));
    });

    testWidgets('a server error tints the banner', (tester) async {
      await pumpPage(
          tester,
          _FakeLoader([
            [_entry('Tárolt')]
          ], refreshed: [
            _listOf(const [], failure: ApiFailure.serverError)
          ]),
          _FakeLocation([found]));

      expect(
          tester
              .widget<Material>(find
                  .descendant(
                      of: find.byType(OfflineBanner),
                      matching: find.byType(Material))
                  .first)
              .color,
          OfflineNotice.serverErrorTint);
      expect(find.byType(OfflineInfoButton), findsOneWidget);
    });

    testWidgets('the (i) tells how old the list is and to pull it down',
        (tester) async {
      await pumpPage(
          tester,
          _FakeLoader([
            [_entry('Tárolt')]
          ], refreshed: [
            _listOf(const [],
                failure: ApiFailure.noConnection,
                dataAsOf: DateTime(2026, 9, 10, 8, 0))
          ]),
          _FakeLocation([found]));

      await tester.tap(find.byType(OfflineInfoButton));
      await tester.pumpAndSettle();

      expect(
          find.text('Az adatok a telefonon tárolt, 2026. 09. 10-i állapotot '
              'mutatják. Frissítéshez kapcsold be az adatkapcsolatot, vagy '
              'ellenőrizd, hogy a Miserend használhat-e mobilnetet a telefon '
              'beállításaiban, majd húzd le a listát.'),
          findsOneWidget);
    });

    testWidgets('pulling down calls the API again, and success clears the '
        'banner', (tester) async {
      final loader = _FakeLoader([
        [_entry('Tárolt')]
      ], refreshed: [
        _listOf(const [], failure: ApiFailure.noConnection),
        _listOf([_entry('Friss')]),
      ]);
      await pumpPage(tester, loader, _FakeLocation([found]));
      expect(find.byType(OfflineBanner), findsOneWidget);

      await pullToRefresh(tester);

      expect(loader.refreshes, 2);
      expect(find.byType(OfflineBanner), findsNothing);
      expect(find.text('Friss'), findsOneWidget);
    });

    testWidgets('no position, no call and no banner', (tester) async {
      final loader = _FakeLoader([<ChurchListEntry>[]],
          refreshed: [_listOf(const [], failure: ApiFailure.noConnection)]);
      await pumpPage(
          tester,
          loader,
          _FakeLocation([
            const PositionUnavailable(PositionUnavailableReason.noFreshFix)
          ]));

      expect(loader.refreshes, 0);
      expect(find.byType(OfflineBanner), findsNothing);
    });
  });
}
