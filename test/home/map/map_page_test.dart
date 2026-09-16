import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:miserend/api/api_result.dart';
import 'package:miserend/colors.dart';
import 'package:miserend/database/cache/church_list_entry.dart';
import 'package:miserend/database/cache/church_location.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/home/churches/church_card.dart';
import 'package:miserend/home/churches/church_list_loader.dart';
import 'package:miserend/home/map/map_page.dart';
import 'package:miserend/home/map/widgets/position_unavailable_banner.dart';
import 'package:miserend/location_provider.dart';
import 'package:miserend/widgets/miserend_map.dart';
import 'package:miserend/widgets/offline_notice.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fake_location_provider.dart';
import '../churches/fake_church_list_loader.dart';

/// Near the default centre, so the markers are on screen.
const _locations = [
  ChurchLocation(id: 1, lat: 47.2537, lon: 19.7523),
  ChurchLocation(id: 2, lat: 47.2600, lon: 19.7600),
];

ChurchListEntry _entry(int id, String name) => ChurchListEntry(
  id: id,
  name: name,
  commonName: null,
  city: 'Kecskemét',
  lat: 47.2537,
  lon: 19.7523,
  photo: null,
  masses: const [],
);

Position _position(double lat, double lon) => Position(
  latitude: lat,
  longitude: lon,
  timestamp: DateTime(2026, 9, 15, 12, 0),
  accuracy: 10,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

class _MapLoader extends FakeChurchListLoader {
  _MapLoader(super.cached, {super.refreshed});

  List<ChurchLocation> locations = _locations;

  /// Bumped by a test in place of an answer written to the cache.
  final ValueNotifier<int> written = ValueNotifier(0);

  @override
  Future<List<ChurchLocation>> churchLocations() async => locations;

  @override
  Listenable get churchesWritten => written;
}

void main() {
  // The card reads favorites, which live in a local database. Built once, in
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

  const noFix = PositionUnavailable(PositionUnavailableReason.noFreshFix);

  Future<MapController> pumpPage(
    WidgetTester tester,
    _MapLoader loader, {
    LocationProvider? location,
  }) async {
    final controller = MapController();
    await tester.pumpWidget(
      ChangeNotifierProvider<FavoritesService>.value(
        value: favorites,
        child: MaterialApp(
          home: Scaffold(
            body: MapPage(
              loader: loader,
              location: location ?? FakeLocationProvider([noFix]),
              mapController: controller,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return controller;
  }

  List<Object?> markerIds(WidgetTester tester) =>
      tester
          .widget<MarkerLayer>(find.byType(MarkerLayer))
          .markers
          .map((marker) => (marker.key as ValueKey).value)
          .toList();

  /// Taps the marker the way a finger on its pin would.
  Future<void> tapMarker(WidgetTester tester, int id) async {
    final marker = tester
        .widget<MarkerLayer>(find.byType(MarkerLayer))
        .markers
        .singleWhere((marker) => (marker.key as ValueKey).value == id);
    (marker.child as GestureDetector).onTap!();
    await tester.pump();
    await tester.pump();
  }

  /// Asks for the position the way the my-position button does, and lets the
  /// answer come back.
  Future<void> tapMyPosition(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.my_location));
    await tester.pump();
    await tester.pump();
  }

  group('markers', () {
    testWidgets('are every church the cache knows', (tester) async {
      await pumpPage(tester, _MapLoader([<ChurchListEntry>[]]));

      expect(markerIds(tester), [1, 2]);
    });

    testWidgets('follow the churches any answer writes into the cache', (
      tester,
    ) async {
      final loader = _MapLoader([<ChurchListEntry>[]]);
      await pumpPage(tester, loader);

      loader.locations = [
        ..._locations,
        const ChurchLocation(id: 3, lat: 47.2650, lon: 19.7650),
      ];
      loader.written.value++;
      await tester.pump();
      await tester.pump();

      expect(markerIds(tester), [1, 2, 3]);
    });

    testWidgets('a church found removed after its card was closed loses its '
        'marker', (tester) async {
      final refresh = Completer<ChurchList>();
      final loader = _MapLoader(
        [
          [_entry(1, 'Megszűnt templom')],
        ],
        refreshed: [refresh],
      );
      await pumpPage(tester, loader);
      await tapMarker(tester, 1);
      await tester.tapAt(const Offset(40, 40));
      await tester.pump(const Duration(milliseconds: 500));

      // The card's refresh deletes the church and says the cache changed.
      loader.locations = [_locations[1]];
      loader.written.value++;
      refresh.complete(
        const ChurchList(
          churches: [],
          failure: null,
          dataAsOf: null,
          removed: [1],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(markerIds(tester), [2]);
      expect(find.byType(ChurchCard), findsNothing);
    });
  });

  group('church card', () {
    testWidgets('appears from the cache at once, while the whole church is '
        'asked for', (tester) async {
      final loader = _MapLoader(
        [
          [_entry(1, 'Tárolt templom')],
        ],
        refreshed: [Completer<ChurchList>()],
      );
      await pumpPage(tester, loader);

      await tapMarker(tester, 1);

      expect(find.text('Tárolt templom'), findsOneWidget);
      final query = loader.queries.single as ChurchCardQuery;
      expect(query.churchId, 1);
      expect(query.minimal, isFalse);
      expect(loader.refreshes, 1);
      expect(find.byType(OfflineInfoButton), findsNothing);
    });

    testWidgets('reads again once the answer is in', (tester) async {
      await pumpPage(
        tester,
        _MapLoader(
          [
            [_entry(1, 'Tárolt templom')],
          ],
          refreshed: [
            listOf([_entry(1, 'Javított templom')]),
          ],
        ),
      );

      await tapMarker(tester, 1);

      expect(find.text('Javított templom'), findsOneWidget);
      expect(find.byType(OfflineInfoButton), findsNothing);
    });

    testWidgets('no connection marks the card with an (i)', (tester) async {
      await pumpPage(
        tester,
        _MapLoader(
          [
            [_entry(1, 'Tárolt templom')],
          ],
          refreshed: [
            listOf(
              const [],
              failure: ApiFailure.noConnection,
              dataAsOf: DateTime(2026, 9, 1, 9, 0),
            ),
          ],
        ),
      );

      await tapMarker(tester, 1);

      expect(find.text('Tárolt templom'), findsOneWidget);
      expect(find.byType(OfflineInfoButton), findsOneWidget);
      final card = tester.widget<Card>(
        find.descendant(
          of: find.byType(ChurchCard),
          matching: find.byType(Card),
        ),
      );
      expect(card.color, isNot(CustomColors.serverErrorTint));

      await tester.tap(find.byType(OfflineInfoButton));
      await tester.pumpAndSettle();
      expect(find.textContaining('2026. 09. 01-i állapotot'), findsOneWidget);
      expect(find.textContaining('nyisd meg újra a templomot'), findsOneWidget);
    });

    testWidgets('a server error tints the card and marks it', (tester) async {
      await pumpPage(
        tester,
        _MapLoader(
          [
            [_entry(1, 'Tárolt templom')],
          ],
          refreshed: [listOf(const [], failure: ApiFailure.serverError)],
        ),
      );

      await tapMarker(tester, 1);

      final card = tester.widget<Card>(
        find.descendant(
          of: find.byType(ChurchCard),
          matching: find.byType(Card),
        ),
      );
      expect(card.color, CustomColors.serverErrorTint);
      expect(find.byType(OfflineInfoButton), findsOneWidget);
    });

    testWidgets('tapping the map away from the markers closes the card', (
      tester,
    ) async {
      await pumpPage(
        tester,
        _MapLoader([
          [_entry(1, 'Tárolt templom')],
        ]),
      );
      await tapMarker(tester, 1);
      expect(find.text('Tárolt templom'), findsOneWidget);

      // Top left, away from the markers near the centre and from the card.
      await tester.tapAt(const Offset(40, 40));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(ChurchCard), findsNothing);
    });

    testWidgets('a church removed from miserend.hu closes the card, loses its '
        'marker and says so', (tester) async {
      await pumpPage(
        tester,
        _MapLoader(
          [
            [_entry(1, 'Megszűnt templom')],
          ],
          refreshed: [
            const ChurchList(
              churches: [],
              failure: null,
              dataAsOf: null,
              removed: [1],
            ),
          ],
        ),
      );

      await tapMarker(tester, 1);

      expect(find.text('Megszűnt templom'), findsNothing);
      expect(markerIds(tester), [2]);
      expect(
        find.text('Ez a templom már nem szerepel a miserend.hu-n.'),
        findsOneWidget,
      );
    });
  });

  group('position', () {
    testWidgets('without a position the map stays on the country', (
      tester,
    ) async {
      final controller = await pumpPage(
        tester,
        _MapLoader([<ChurchListEntry>[]]),
      );

      expect(controller.camera.center, MiserendMap.defaultInitialCenter);
      expect(
        find.byType(PositionUnavailableBanner),
        findsNothing,
        reason: 'the automatic attempt at opening stays quiet',
      );
    });

    testWidgets('with a position the map moves there', (tester) async {
      final controller = await pumpPage(
        tester,
        _MapLoader([<ChurchListEntry>[]]),
        location: FakeLocationProvider([PositionFound(_position(47.5, 19.04))]),
      );

      expect(controller.camera.center, const LatLng(47.5, 19.04));
    });

    const cases = {
      PositionUnavailableReason.permissionDenied: (
        'A helyzeted mutatásához engedélyezd a helyadatot.',
        'Engedélyezés',
      ),
      PositionUnavailableReason.permissionDeniedForever: (
        'A helyzeted mutatásához engedélyezd a helyadatot a telefon '
            'beállításaiban.',
        'Beállítások megnyitása',
      ),
      PositionUnavailableReason.serviceDisabled: (
        'A helyzeted mutatásához kapcsold be a helymeghatározást.',
        'Beállítások megnyitása',
      ),
      PositionUnavailableReason.noFreshFix: (
        'Nem sikerült meghatározni a helyzetedet.',
        null,
      ),
    };

    for (final MapEntry(key: reason, value: (text, action)) in cases.entries) {
      testWidgets('my-position button, ${reason.name}: a strip with the '
          'reason and its way out', (tester) async {
        await pumpPage(
          tester,
          _MapLoader([<ChurchListEntry>[]]),
          location: FakeLocationProvider([PositionUnavailable(reason)]),
        );

        await tapMyPosition(tester);

        expect(tester.takeException(), isNull);
        expect(find.text(text), findsOneWidget);
        expect(
          find.byType(SnackBar),
          findsNothing,
          reason: 'a SnackBar with an action never goes away (issue #23)',
        );
        if (action == null) {
          expect(
            find.descendant(
              of: find.byType(PositionUnavailableBanner),
              matching: find.byType(TextButton),
            ),
            findsNothing,
          );
        } else {
          expect(find.widgetWithText(TextButton, action), findsOneWidget);
        }
      });
    }

    testWidgets('the church card and the my-position button stay whole next '
        'to the strip', (tester) async {
      await pumpPage(
        tester,
        _MapLoader([
          [_entry(1, 'Tárolt templom')],
        ]),
        location: FakeLocationProvider([
          const PositionUnavailable(
            PositionUnavailableReason.permissionDeniedForever,
          ),
        ]),
      );
      await tapMyPosition(tester);
      await tapMarker(tester, 1);

      final strip = tester.getRect(find.byType(PositionUnavailableBanner));
      expect(
        tester.getRect(find.byType(ChurchCard)).bottom,
        lessThanOrEqualTo(strip.top),
      );
      expect(
        tester.getRect(find.byType(FloatingActionButton)).bottom,
        lessThanOrEqualTo(strip.top),
      );
    });

    testWidgets('allowing the permission from the strip moves the map and '
        'puts the strip away', (tester) async {
      final location = FakeLocationProvider([
        noFix,
        const PositionUnavailable(PositionUnavailableReason.permissionDenied),
        PositionFound(_position(47.5, 19.04)),
      ]);
      final controller = await pumpPage(
        tester,
        _MapLoader([<ChurchListEntry>[]]),
        location: location,
      );

      await tapMyPosition(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Engedélyezés'));
      await tester.pump();
      await tester.pump();

      expect(controller.camera.center, const LatLng(47.5, 19.04));
      expect(find.byType(PositionUnavailableBanner), findsNothing);
    });

    testWidgets('the strip can be closed by hand, and the my-position button '
        'brings it back', (tester) async {
      await pumpPage(
        tester,
        _MapLoader([<ChurchListEntry>[]]),
        location: FakeLocationProvider([
          const PositionUnavailable(PositionUnavailableReason.serviceDisabled),
        ]),
      );

      await tapMyPosition(tester);
      expect(find.byType(PositionUnavailableBanner), findsOneWidget);

      await tester.tap(find.byTooltip('Bezárás'));
      await tester.pump();
      expect(find.byType(PositionUnavailableBanner), findsNothing);

      await tapMyPosition(tester);
      expect(find.byType(PositionUnavailableBanner), findsOneWidget);
    });

    testWidgets('the strip belongs to the map tab, and another tab does not '
        'show it', (tester) async {
      final semantics = tester.ensureSemantics();
      const text = 'A helyzeted mutatásához kapcsold be a helymeghatározást.';
      await tester.pumpWidget(
        ChangeNotifierProvider<FavoritesService>.value(
          value: favorites,
          child: MaterialApp(
            home: _TabsHost(
              map: MapPage(
                loader: _MapLoader([<ChurchListEntry>[]]),
                location: FakeLocationProvider([
                  const PositionUnavailable(
                    PositionUnavailableReason.serviceDisabled,
                  ),
                ]),
                mapController: MapController(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tapMyPosition(tester);
      expect(find.bySemanticsLabel(text), findsOneWidget);

      await tester.tap(find.text('Templomok'));
      await tester.pump();

      // The IndexedStack keeps the map alive but stops showing it, semantics
      // included. A SnackBar would have hung above the stack instead, on
      // every tab and for good (issue #23).
      expect(find.bySemanticsLabel(text), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      semantics.dispose();
    });

    testWidgets('the settings button opens the location settings, and coming '
        'back tries again', (tester) async {
      final location = FakeLocationProvider([
        noFix,
        const PositionUnavailable(PositionUnavailableReason.serviceDisabled),
        PositionFound(_position(47.5, 19.04)),
      ]);
      final controller = await pumpPage(
        tester,
        _MapLoader([<ChurchListEntry>[]]),
        location: location,
      );

      await tapMyPosition(tester);
      await tester.tap(
        find.widgetWithText(TextButton, 'Beállítások megnyitása'),
      );
      await tester.pump();
      expect(location.locationSettingsOpened, 1);

      final binding = tester.binding;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(controller.camera.center, const LatLng(47.5, 19.04));
      expect(find.byType(PositionUnavailableBanner), findsNothing);
    });
  });
}

/// The shape home.dart gives the tabs: one ScaffoldMessenger above an
/// IndexedStack that keeps every tab it has built alive. HomeScreen itself
/// builds `const MapPage()` with nothing to inject, and its other tabs reach
/// for the real database and API, so the shape is rebuilt here instead.
class _TabsHost extends StatefulWidget {
  const _TabsHost({required this.map});

  final Widget map;

  @override
  State<_TabsHost> createState() => _TabsHostState();
}

class _TabsHostState extends State<_TabsHost> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        sizing: StackFit.expand,
        children: [widget.map, const Center(child: Text('Másik fül'))],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Térkép'),
          BottomNavigationBarItem(icon: Icon(Icons.church), label: 'Templomok'),
        ],
        currentIndex: _index,
        onTap: (index) => setState(() => _index = index),
      ),
    );
  }
}
