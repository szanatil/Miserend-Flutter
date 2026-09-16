import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miserend/database/cache/cached_mass.dart';
import 'package:miserend/database/cache/church_list_entry.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/home/churches/church_card.dart';
import 'package:miserend/widgets/distance_chip.dart';
import 'package:miserend/widgets/time_chip.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Kecskemét's main square; the church stands about 300 m away.
const _position = LatLng(46.9062, 19.6913);

CachedMass _mass(int hour, int minute) => CachedMass(
  id: null,
  apiMassId: null,
  churchId: 1,
  time: DateTime(2026, 9, 15, hour, minute),
  info: null,
  source: MassSource.bootstrap,
);

ChurchListEntry _entry({
  String name = 'Nagytemplom',
  String? commonName = 'Szent Miklós',
  double? lat = 46.9089,
  double? lon = 19.6913,
  List<CachedMass> masses = const [],
}) => ChurchListEntry(
  id: 1,
  name: name,
  commonName: commonName,
  city: 'Kecskemét',
  lat: lat,
  lon: lon,
  photo: null,
  masses: masses,
);

void main() {
  // The heart reads favorites, which live in a local database. Built once, in
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

  Future<void> pumpCard(
    WidgetTester tester,
    ChurchListEntry entry, {
    LatLng? position,
    double width = 400,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<FavoritesService>.value(
        value: favorites,
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: ChurchCard(entry: entry, position: position),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('distance', () {
    testWidgets('shows the straight-line distance from the position', (
      tester,
    ) async {
      await pumpCard(tester, _entry(), position: _position);

      expect(find.byType(DistanceChip), findsOneWidget);
      expect(find.text('300 m'), findsOneWidget);
    });

    testWidgets('sits in the bottom right corner of the photo', (tester) async {
      await pumpCard(tester, _entry(), position: _position);

      final photo = tester.getRect(find.byType(Image));
      final chip = tester.getRect(find.byType(DistanceChip));
      expect(photo.right - chip.right, 8);
      expect(photo.bottom - chip.bottom, 8);
    });

    testWidgets('is left out without a position, and moves nothing', (
      tester,
    ) async {
      await pumpCard(tester, _entry(), position: _position);
      final heart = tester.getTopLeft(find.byType(IconButton));

      await pumpCard(tester, _entry());

      expect(find.byType(DistanceChip), findsNothing);
      expect(tester.getTopLeft(find.byType(IconButton)), heart);
      expect(find.text('Nagytemplom'), findsOneWidget);
      expect(find.text('Szent Miklós'), findsOneWidget);
    });

    for (final (lat, lon) in [(null, 19.6913), (46.9089, null), (0.0, 0.0)]) {
      testWidgets('is left out for a church at ($lat, $lon)', (tester) async {
        await pumpCard(tester, _entry(lat: lat, lon: lon), position: _position);

        expect(find.byType(DistanceChip), findsNothing);
      });
    }
  });

  group('layout', () {
    const longName =
        'Kecskeméti Szent Miklós Ferences Templom és Kolostor Plébánia '
        'Templom Alsóvárosi Rész Nagyon Hosszú Névvel';
    const longCommonName =
        'Alsóvárosi templom, Ferences templom, Barátok temploma';

    testWidgets('a long name and a long common name do not overflow', (
      tester,
    ) async {
      await pumpCard(
        tester,
        _entry(name: longName, commonName: longCommonName),
        position: _position,
        width: 360,
      );

      expect(tester.takeException(), isNull);
      expect(tester.widget<Text>(find.text(longName)).maxLines, 2);
      expect(tester.widget<Text>(find.text(longCommonName)).maxLines, 1);
    });

    testWidgets('the mass chips and the heart stand at the same height '
        'whatever the names', (tester) async {
      final masses = [_mass(8, 0)];
      await pumpCard(
        tester,
        _entry(name: 'Rövid', commonName: null, masses: masses),
      );
      final chip = tester.getTopLeft(find.byType(TimeChip));
      final heart = tester.getTopLeft(find.byType(IconButton));

      await pumpCard(
        tester,
        _entry(name: longName, commonName: longCommonName, masses: masses),
      );

      expect(tester.getTopLeft(find.byType(TimeChip)).dy, chip.dy);
      expect(tester.getTopLeft(find.byType(IconButton)).dy, heart.dy);
    });

    testWidgets('masses that do not fit on one line give way to a „…" chip', (
      tester,
    ) async {
      await pumpCard(
        tester,
        _entry(masses: [for (var hour = 6; hour < 20; hour++) _mass(hour, 30)]),
        width: 320,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('…'), findsOneWidget);
      expect(find.text('19:30'), findsNothing);
      final tops = {
        for (final element in find.byType(TimeChip).evaluate())
          tester.getTopLeft(find.byWidget(element.widget)).dy,
      };
      expect(tops, hasLength(1));
      final photo = tester.getRect(find.byType(Image));
      for (final element in find.byType(TimeChip).evaluate()) {
        expect(
          tester.getRect(find.byWidget(element.widget)).right,
          lessThanOrEqualTo(photo.left),
        );
      }
    });

    testWidgets('every mass shows, with no „…" chip, while all of them fit', (
      tester,
    ) async {
      await pumpCard(tester, _entry(masses: [_mass(8, 0), _mass(18, 0)]));

      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('18:00'), findsOneWidget);
      expect(find.text('…'), findsNothing);
    });
  });
}
