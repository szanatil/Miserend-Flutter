import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:miserend/api/api_result.dart';
import 'package:miserend/colors.dart';
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

import '../../fake_location_provider.dart';
import 'fake_church_list_loader.dart';

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
    ChurchListLoader loader,
    LocationProvider location,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<FavoritesService>.value(
        value: favorites,
        child: MaterialApp(
          home: Scaffold(
            body: NearChurchesPage(loader: loader, location: location),
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

  final found = PositionFound(_position());

  group('states', () {
    testWidgets('shows the loading caption while the cache is read', (
      tester,
    ) async {
      await pumpPage(
        tester,
        FakeChurchListLoader([Completer<List<ChurchListEntry>>()]),
        FakeLocationProvider([found]),
      );

      expect(find.text('Közeli templomok betöltése...'), findsOneWidget);
    });

    testWidgets('says so when there is no church nearby', (tester) async {
      await pumpPage(
        tester,
        FakeChurchListLoader([<ChurchListEntry>[]]),
        FakeLocationProvider([found]),
      );

      expect(find.text('Nem találhatóak közeli templomok.'), findsOneWidget);
    });

    testWidgets('lists the churches in the order the cache gives them', (
      tester,
    ) async {
      await pumpPage(
        tester,
        FakeChurchListLoader([
          [_entry('Közelebbi'), _entry('Távolabbi')],
        ]),
        FakeLocationProvider([found]),
      );

      expect(find.text('Közelebbi'), findsOneWidget);
      expect(find.text('Távolabbi'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Közelebbi')).dy,
        lessThan(tester.getTopLeft(find.text('Távolabbi')).dy),
      );
    });

    testWidgets('a row shows masses only, not confession or adoration', (
      tester,
    ) async {
      await pumpPage(
        tester,
        FakeChurchListLoader([
          [
            _entry(
              'Templom',
              masses: [
                _row(7, 'Szentmise', MassSource.nearbyMasses),
                _row(9, 'Gyóntatás', MassSource.nearbyMasses),
                _row(18, 'gitáros', MassSource.bootstrap),
              ],
            ),
          ],
        ]),
        FakeLocationProvider([found]),
      );

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
        'Engedélyezés',
      ),
      PositionUnavailableReason.permissionDeniedForever: (
        'A közeli templomokhoz engedélyezd a helyadatot a telefon '
            'beállításaiban.',
        'Beállítások megnyitása',
      ),
      PositionUnavailableReason.serviceDisabled: (
        'A közeli templomokhoz kapcsold be a helymeghatározást.',
        'Beállítások megnyitása',
      ),
      PositionUnavailableReason.noFreshFix: (
        'Nem sikerült meghatározni a helyzetedet.',
        null,
      ),
    };

    for (final MapEntry(key: reason, value: (text, button)) in cases.entries) {
      testWidgets('${reason.name}: the reason and its way out', (tester) async {
        final loader = FakeChurchListLoader([<ChurchListEntry>[]]);
        await pumpPage(
          tester,
          loader,
          FakeLocationProvider([PositionUnavailable(reason)]),
        );

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
      final location = FakeLocationProvider([
        const PositionUnavailable(PositionUnavailableReason.permissionDenied),
        found,
      ]);
      await pumpPage(
        tester,
        FakeChurchListLoader([
          [_entry('Templom')],
        ]),
        location,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Engedélyezés'));
      await tester.pump();
      await tester.pump();

      expect(location.calls, 2);
      expect(find.text('Templom'), findsOneWidget);
    });

    testWidgets('denied for good opens the app settings', (tester) async {
      final location = FakeLocationProvider([
        const PositionUnavailable(
          PositionUnavailableReason.permissionDeniedForever,
        ),
      ]);
      await pumpPage(
        tester,
        FakeChurchListLoader([<ChurchListEntry>[]]),
        location,
      );

      await tester.tap(
        find.widgetWithText(FilledButton, 'Beállítások megnyitása'),
      );

      expect(location.appSettingsOpened, 1);
      expect(location.locationSettingsOpened, 0);
    });

    testWidgets('location services off opens the location settings', (
      tester,
    ) async {
      final location = FakeLocationProvider([
        const PositionUnavailable(PositionUnavailableReason.serviceDisabled),
      ]);
      await pumpPage(
        tester,
        FakeChurchListLoader([<ChurchListEntry>[]]),
        location,
      );

      await tester.tap(
        find.widgetWithText(FilledButton, 'Beállítások megnyitása'),
      );

      expect(location.locationSettingsOpened, 1);
      expect(location.appSettingsOpened, 0);
    });

    testWidgets('coming back from the settings tries the position again', (
      tester,
    ) async {
      final location = FakeLocationProvider([
        const PositionUnavailable(PositionUnavailableReason.serviceDisabled),
        found,
      ]);
      await pumpPage(
        tester,
        FakeChurchListLoader([
          [_entry('Templom')],
        ]),
        location,
      );

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
    testWidgets('asks for the position again and reads the cache again', (
      tester,
    ) async {
      final location = FakeLocationProvider([found]);
      final loader = FakeChurchListLoader([
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
      final location = FakeLocationProvider([
        const PositionUnavailable(PositionUnavailableReason.noFreshFix),
        found,
      ]);
      await pumpPage(
        tester,
        FakeChurchListLoader([
          [_entry('Templom')],
        ]),
        location,
      );

      await pullToRefresh(tester);

      expect(find.text('Templom'), findsOneWidget);
    });
  });

  group('background refresh', () {
    testWidgets('asks around the position the list was read for', (
      tester,
    ) async {
      final loader = FakeChurchListLoader([
        [_entry('Templom')],
      ]);
      await pumpPage(tester, loader, FakeLocationProvider([found]));

      final query = loader.queries.single as NearChurchesQuery;
      expect((query.lat, query.lon), (47.4979, 19.0402));
      expect(loader.refreshes, 1);
    });

    testWidgets('shows the cached list and no mark while the call runs', (
      tester,
    ) async {
      await pumpPage(
        tester,
        FakeChurchListLoader(
          [
            [_entry('Tárolt')],
          ],
          refreshed: [Completer<ChurchList>()],
        ),
        FakeLocationProvider([found]),
      );

      expect(find.text('Tárolt'), findsOneWidget);
      expect(find.byType(OfflineBanner), findsNothing);
    });

    testWidgets('a new church from the answer appears in the list', (
      tester,
    ) async {
      await pumpPage(
        tester,
        FakeChurchListLoader(
          [
            [_entry('Tárolt')],
          ],
          refreshed: [
            listOf([_entry('Tárolt'), _entry('Új templom')]),
          ],
        ),
        FakeLocationProvider([found]),
      );

      expect(find.text('Új templom'), findsOneWidget);
      expect(find.byType(OfflineBanner), findsNothing);
    });

    testWidgets('no connection puts the banner above the list, untinted', (
      tester,
    ) async {
      await pumpPage(
        tester,
        FakeChurchListLoader(
          [
            [_entry('Tárolt')],
          ],
          refreshed: [listOf(const [], failure: ApiFailure.noConnection)],
        ),
        FakeLocationProvider([found]),
      );

      expect(find.text('Tárolt'), findsOneWidget);
      expect(find.byType(OfflineBanner), findsOneWidget);
      expect(find.byType(OfflineInfoButton), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(OfflineBanner)).dy,
        lessThan(tester.getTopLeft(find.text('Tárolt')).dy),
      );
      expect(
        tester
            .widget<Material>(
              find
                  .descendant(
                    of: find.byType(OfflineBanner),
                    matching: find.byType(Material),
                  )
                  .first,
            )
            .color,
        isNot(CustomColors.serverErrorTint),
      );
    });

    testWidgets('a server error tints the banner', (tester) async {
      await pumpPage(
        tester,
        FakeChurchListLoader(
          [
            [_entry('Tárolt')],
          ],
          refreshed: [listOf(const [], failure: ApiFailure.serverError)],
        ),
        FakeLocationProvider([found]),
      );

      expect(
        tester
            .widget<Material>(
              find
                  .descendant(
                    of: find.byType(OfflineBanner),
                    matching: find.byType(Material),
                  )
                  .first,
            )
            .color,
        CustomColors.serverErrorTint,
      );
      expect(find.byType(OfflineInfoButton), findsOneWidget);
    });

    testWidgets('the (i) tells how old the list is and to pull it down', (
      tester,
    ) async {
      await pumpPage(
        tester,
        FakeChurchListLoader(
          [
            [_entry('Tárolt')],
          ],
          refreshed: [
            listOf(
              const [],
              failure: ApiFailure.noConnection,
              dataAsOf: DateTime(2026, 9, 10, 8, 0),
            ),
          ],
        ),
        FakeLocationProvider([found]),
      );

      await tester.tap(find.byType(OfflineInfoButton));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Az adatok a telefonon tárolt, 2026. 09. 10-i állapotot mutatják. '
          'Kapcsold be az adatkapcsolatot, vagy ellenőrizd, hogy a '
          'Miserend használhat-e mobilnetet a telefon beállításaiban — '
          'amint újra van kapcsolat, a képernyő magától frissül.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('pulling down calls the API again, and success clears the '
        'banner', (tester) async {
      final loader = FakeChurchListLoader(
        [
          [_entry('Tárolt')],
        ],
        refreshed: [
          listOf(const [], failure: ApiFailure.noConnection),
          listOf([_entry('Friss')]),
        ],
      );
      await pumpPage(tester, loader, FakeLocationProvider([found]));
      expect(find.byType(OfflineBanner), findsOneWidget);

      await pullToRefresh(tester);

      expect(loader.refreshes, 2);
      expect(find.byType(OfflineBanner), findsNothing);
      expect(find.text('Friss'), findsOneWidget);
    });

    testWidgets('no banner while a pulled refresh runs; a failure puts it '
        'back', (tester) async {
      final retry = Completer<ChurchList>();
      final loader = FakeChurchListLoader(
        [
          [_entry('Tárolt')],
        ],
        refreshed: [listOf(const [], failure: ApiFailure.noConnection), retry],
      );
      await pumpPage(tester, loader, FakeLocationProvider([found]));
      expect(find.byType(OfflineBanner), findsOneWidget);

      await pullToRefresh(tester);
      expect(find.byType(OfflineBanner), findsNothing);
      expect(find.text('Tárolt'), findsOneWidget);

      retry.complete(
        listOf([_entry('Tárolt')], failure: ApiFailure.noConnection),
      );
      await tester.pump();
      expect(find.byType(OfflineBanner), findsOneWidget);
    });

    testWidgets('no position, no call and no banner', (tester) async {
      final loader = FakeChurchListLoader(
        [<ChurchListEntry>[]],
        refreshed: [listOf(const [], failure: ApiFailure.noConnection)],
      );
      await pumpPage(
        tester,
        loader,
        FakeLocationProvider([
          const PositionUnavailable(PositionUnavailableReason.noFreshFix),
        ]),
      );

      expect(loader.refreshes, 0);
      expect(find.byType(OfflineBanner), findsNothing);
    });
  });
}
