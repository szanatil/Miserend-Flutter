import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/api/nearby_masses_item.dart';
import 'package:miserend/home/masses/mass_card.dart';
import 'package:miserend/widgets/distance_chip.dart';

NearbyMassesItem _mass({
  String name = 'Szent Miklós-templom',
  String? city = 'Nyíregyháza',
  String? title = 'Szentmise',
  DateTime? start,
}) {
  return NearbyMassesItem(
    churchId: 1,
    churchName: name,
    city: city,
    lat: 47.95,
    lon: 21.72,
    distanceKm: 1.23,
    start: start ?? _at(18, 0),
    title: title,
  );
}

DateTime _at(int hour, int minute) => DateTime(2026, 9, 14, hour, minute);

/// The blurred church placeholder, looking through the resize wrapper that
/// decoding at the photo strip's size puts around it.
Finder _photo() => find.byWidgetPredicate((widget) {
  if (widget is! Image) return false;
  var provider = widget.image;
  if (provider is ResizeImage) provider = provider.imageProvider;
  return provider is AssetImage &&
      provider.assetName == 'assets/images/church_blurred.png';
});

void main() {
  Future<void> pumpCard(
    WidgetTester tester,
    NearbyMassesItem mass, {
    DateTime? now,
    double width = 400,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: MassCard(
                  mass: mass,
                  now: now ?? _at(12, 0),
                  thumbnailUrl: Future.value(null),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('time', () {
    testWidgets('shows the start and, within two hours, the time until it', (
      tester,
    ) async {
      await pumpCard(tester, _mass(start: _at(18, 0)), now: _at(17, 35));

      expect(find.text('18:00'), findsOneWidget);
      expect(find.text('25 perc múlva'), findsOneWidget);
      expect(find.text('Épp most tart'), findsNothing);
    });

    testWidgets('an ongoing mass is marked as such, with no time until', (
      tester,
    ) async {
      await pumpCard(tester, _mass(start: _at(18, 0)), now: _at(18, 4));

      expect(find.text('18:00'), findsOneWidget);
      expect(find.text('Épp most tart'), findsOneWidget);
      expect(find.textContaining('múlva'), findsNothing);
    });

    testWidgets('a mass more than two hours away shows the start alone', (
      tester,
    ) async {
      await pumpCard(tester, _mass(start: _at(18, 0)), now: _at(12, 0));

      expect(find.text('18:00'), findsOneWidget);
      expect(find.textContaining('múlva'), findsNothing);
      expect(find.text('Épp most tart'), findsNothing);
    });

    for (final textScale in [1.0, 2.0]) {
      testWidgets('every card is the same height at text scale $textScale, '
          'whatever the time column says', (tester) async {
        final heights = <double>[];
        for (final now in [_at(18, 4), _at(17, 1), _at(12, 0)]) {
          await pumpCard(
            tester,
            _mass(name: 'Rövid'),
            now: now,
            width: 360,
            textScale: textScale,
          );
          heights.add(tester.getSize(find.byType(MassCard)).height);
        }

        expect(tester.takeException(), isNull);
        expect(heights.toSet(), hasLength(1));
      });
    }

    testWidgets('the church column starts at the same place whatever the time '
        'column says', (tester) async {
      await pumpCard(tester, _mass(start: _at(18, 0)), now: _at(18, 4));
      final besideOngoing = tester.getTopLeft(
        find.text('Szent Miklós-templom'),
      );

      await pumpCard(tester, _mass(start: _at(18, 0)), now: _at(12, 0));
      final besideStartAlone = tester.getTopLeft(
        find.text('Szent Miklós-templom'),
      );

      expect(besideStartAlone, besideOngoing);
    });
  });

  group('church', () {
    testWidgets('leaves plain Szentmise out of the city line', (tester) async {
      await pumpCard(tester, _mass(title: 'Szentmise'));

      expect(find.text('Nyíregyháza'), findsOneWidget);
      expect(find.textContaining('Szentmise'), findsNothing);
    });

    testWidgets('puts any other title after the city', (tester) async {
      await pumpCard(tester, _mass(title: 'Szent Liturgia'));

      expect(find.text('Nyíregyháza · Szent Liturgia'), findsOneWidget);
    });

    testWidgets('shows the title alone when there is no city', (tester) async {
      await pumpCard(tester, _mass(city: null, title: 'Szent Liturgia'));

      expect(find.text('Szent Liturgia'), findsOneWidget);
    });

    testWidgets('the line under the name stands at the same height for a short '
        'and a long name', (tester) async {
      await pumpCard(tester, _mass(name: 'Rövid'));
      final underShort = tester.getTopLeft(find.text('Nyíregyháza')).dy;

      await pumpCard(
        tester,
        _mass(
          name:
              'Nagyboldogasszony görögkatolikus székesegyház és '
              'püspöki templom',
        ),
      );
      final underLong = tester.getTopLeft(find.text('Nyíregyháza')).dy;

      expect(underLong, underShort);
    });

    testWidgets('long texts at a large text size do not overflow', (
      tester,
    ) async {
      await pumpCard(
        tester,
        _mass(
          name:
              'Nagyboldogasszony görögkatolikus székesegyház és '
              'püspöki templom',
          city: 'Budapest XVIII. kerület, Pestszentlőrinc-Pestszentimre',
          title: 'Régi rítusú szentmise',
          start: _at(18, 0),
        ),
        now: _at(18, 4),
        width: 360,
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('photo', () {
    testWidgets('runs the full height of the card to its right edge', (
      tester,
    ) async {
      await pumpCard(tester, _mass());

      // The card's surface, inside the margin around it.
      final card = tester.getRect(
        find
            .descendant(of: find.byType(Card), matching: find.byType(Material))
            .first,
      );
      final photo = tester.getRect(_photo());
      expect(photo.right, card.right);
      expect(photo.top, card.top);
      expect(photo.bottom, card.bottom);
    });

    testWidgets('carries the distance in its bottom right corner', (
      tester,
    ) async {
      await pumpCard(tester, _mass());

      final photo = tester.getRect(_photo());
      final chip = tester.getRect(find.byType(DistanceChip));
      expect(
        find.descendant(
          of: find.byType(DistanceChip),
          matching: find.text('1,2 km'),
        ),
        findsOneWidget,
      );
      expect(photo.right - chip.right, 8);
      expect(photo.bottom - chip.bottom, 8);
    });
  });

  testWidgets('has no favorite button', (tester) async {
    await pumpCard(tester, _mass());

    expect(find.byType(IconButton), findsNothing);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
  });

  testWidgets('tapping anywhere on the card calls onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MassCard(
            mass: _mass(),
            now: _at(12, 0),
            thumbnailUrl: Future.value(null),
            onTap: () => taps++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('18:00'));
    await tester.tap(_photo());

    expect(taps, 2);
  });
}
