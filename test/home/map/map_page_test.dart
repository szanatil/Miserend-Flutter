import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:miserend/api/api_result.dart';
import 'package:miserend/database/cache/church_list_entry.dart';
import 'package:miserend/database/cache/church_location.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/home/churches/church_card.dart';
import 'package:miserend/home/churches/church_list_loader.dart';
import 'package:miserend/home/map/map_page.dart';
import 'package:miserend/location_provider.dart';
import 'package:miserend/widgets/miserend_map.dart';
import 'package:miserend/widgets/offline_notice.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

  @override
  Future<List<ChurchLocation>> churchLocations() async => locations;
}

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

  Future<MapController> pumpPage(WidgetTester tester, _MapLoader loader,
      {LocationProvider? location}) async {
    final controller = MapController();
    await tester.pumpWidget(ChangeNotifierProvider<FavoritesService>.value(
      value: favorites,
      child: MaterialApp(
        home: Scaffold(
          body: MapPage(
            loader: loader,
            location: location ?? _FakeLocation([noFix]),
            mapController: controller,
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();
    return controller;
  }

  List<Object?> markerIds(WidgetTester tester) => tester
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

  /// Lets the SnackBar slide in, so that its action can be tapped.
  Future<void> showSnackBar(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  group('markers', () {
    testWidgets('are every church the cache knows', (tester) async {
      await pumpPage(tester, _MapLoader([<ChurchListEntry>[]]));

      expect(markerIds(tester), [1, 2]);
    });
  });

  group('church card', () {
    testWidgets('appears from the cache at once, while the whole church is '
        'asked for', (tester) async {
      final loader = _MapLoader([
        [_entry(1, 'Tárolt templom')]
      ], refreshed: [
        Completer<ChurchList>()
      ]);
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
          _MapLoader([
            [_entry(1, 'Tárolt templom')]
          ], refreshed: [
            listOf([_entry(1, 'Javított templom')])
          ]));

      await tapMarker(tester, 1);

      expect(find.text('Javított templom'), findsOneWidget);
      expect(find.byType(OfflineInfoButton), findsNothing);
    });

    testWidgets('no connection marks the card with an (i)', (tester) async {
      await pumpPage(
          tester,
          _MapLoader([
            [_entry(1, 'Tárolt templom')]
          ], refreshed: [
            listOf(const [],
                failure: ApiFailure.noConnection,
                dataAsOf: DateTime(2026, 9, 1, 9, 0))
          ]));

      await tapMarker(tester, 1);

      expect(find.text('Tárolt templom'), findsOneWidget);
      expect(find.byType(OfflineInfoButton), findsOneWidget);
      final card = tester.widget<Card>(find.descendant(
          of: find.byType(ChurchCard), matching: find.byType(Card)));
      expect(card.color, isNot(OfflineNotice.serverErrorTint));

      await tester.tap(find.byType(OfflineInfoButton));
      await tester.pumpAndSettle();
      expect(find.textContaining('2026. 09. 01-i állapotot'), findsOneWidget);
      expect(find.textContaining('nyisd meg újra a templomot'), findsOneWidget);
    });

    testWidgets('a server error tints the card and marks it', (tester) async {
      await pumpPage(
          tester,
          _MapLoader([
            [_entry(1, 'Tárolt templom')]
          ], refreshed: [
            listOf(const [], failure: ApiFailure.serverError)
          ]));

      await tapMarker(tester, 1);

      final card = tester.widget<Card>(find.descendant(
          of: find.byType(ChurchCard), matching: find.byType(Card)));
      expect(card.color, OfflineNotice.serverErrorTint);
      expect(find.byType(OfflineInfoButton), findsOneWidget);
    });

    testWidgets('tapping the map away from the markers closes the card',
        (tester) async {
      await pumpPage(
          tester,
          _MapLoader([
            [_entry(1, 'Tárolt templom')]
          ]));
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
          _MapLoader([
            [_entry(1, 'Megszűnt templom')]
          ], refreshed: [
            const ChurchList(
                churches: [], failure: null, dataAsOf: null, removed: [1])
          ]));

      await tapMarker(tester, 1);

      expect(find.text('Megszűnt templom'), findsNothing);
      expect(markerIds(tester), [2]);
      expect(find.text('Ez a templom már nem szerepel a miserend.hu-n.'),
          findsOneWidget);
    });
  });

  group('position', () {
    testWidgets('without a position the map stays on the country',
        (tester) async {
      final controller = await pumpPage(tester, _MapLoader([<ChurchListEntry>[]]));

      expect(controller.camera.center, MiserendMap.defaultInitialCenter);
      expect(find.byType(SnackBar), findsNothing,
          reason: 'the automatic attempt at opening stays quiet');
    });

    testWidgets('with a position the map moves there', (tester) async {
      final controller = await pumpPage(tester, _MapLoader([<ChurchListEntry>[]]),
          location: _FakeLocation([PositionFound(_position(47.5, 19.04))]));

      expect(controller.camera.center, const LatLng(47.5, 19.04));
    });

    const cases = {
      PositionUnavailableReason.permissionDenied: (
        'A helyzeted mutatásához engedélyezd a helyadatot.',
        'Engedélyezés'
      ),
      PositionUnavailableReason.permissionDeniedForever: (
        'A helyzeted mutatásához engedélyezd a helyadatot a telefon '
            'beállításaiban.',
        'Beállítások megnyitása'
      ),
      PositionUnavailableReason.serviceDisabled: (
        'A helyzeted mutatásához kapcsold be a helymeghatározást.',
        'Beállítások megnyitása'
      ),
      PositionUnavailableReason.noFreshFix: (
        'Nem sikerült meghatározni a helyzetedet.',
        null
      ),
    };

    for (final MapEntry(key: reason, value: (text, action)) in cases.entries) {
      testWidgets('my-position button, ${reason.name}: a SnackBar with the '
          'reason and its way out', (tester) async {
        await pumpPage(tester, _MapLoader([<ChurchListEntry>[]]),
            location: _FakeLocation([PositionUnavailable(reason)]));

        await tester.tap(find.byIcon(Icons.my_location));
        await tester.pump();
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text(text), findsOneWidget);
        if (action == null) {
          expect(find.byType(SnackBarAction), findsNothing);
        } else {
          expect(find.widgetWithText(SnackBarAction, action), findsOneWidget);
        }
      });
    }

    testWidgets('allowing the permission from the SnackBar moves the map',
        (tester) async {
      final location = _FakeLocation([
        noFix,
        const PositionUnavailable(PositionUnavailableReason.permissionDenied),
        PositionFound(_position(47.5, 19.04)),
      ]);
      final controller =
          await pumpPage(tester, _MapLoader([<ChurchListEntry>[]]), location: location);

      await tester.tap(find.byIcon(Icons.my_location));
      await showSnackBar(tester);
      await tester.tap(find.widgetWithText(SnackBarAction, 'Engedélyezés'));
      await tester.pump();
      await tester.pump();

      expect(controller.camera.center, const LatLng(47.5, 19.04));
    });

    testWidgets('the settings action opens the location settings, and coming '
        'back tries again', (tester) async {
      final location = _FakeLocation([
        noFix,
        const PositionUnavailable(PositionUnavailableReason.serviceDisabled),
        PositionFound(_position(47.5, 19.04)),
      ]);
      final controller =
          await pumpPage(tester, _MapLoader([<ChurchListEntry>[]]), location: location);

      await tester.tap(find.byIcon(Icons.my_location));
      await showSnackBar(tester);
      await tester
          .tap(find.widgetWithText(SnackBarAction, 'Beállítások megnyitása'));
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
    });
  });
}
