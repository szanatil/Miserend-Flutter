import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/api/nearby_masses_item.dart';
import 'package:miserend/home/masses/mass_start_header.dart';
import 'package:miserend/theme/tokens.dart';
import 'package:miserend/widgets/status_badge.dart';

import '../../theme/theme_harness.dart';

NearbyMassesItem _mass(DateTime start) => NearbyMassesItem(
  churchId: 1,
  churchName: 'Szent Miklós-templom',
  city: 'Nyíregyháza',
  lat: 47.95,
  lon: 21.72,
  distanceKm: 1.23,
  start: start,
  title: 'Szentmise',
);

DateTime _at(int hour, int minute) => DateTime(2026, 9, 14, hour, minute);

/// The container the start stands in.
ShapeDecoration _timeContainer(WidgetTester tester, String time) =>
    tester
            .widget<DecoratedBox>(
              find
                  .ancestor(
                    of: find.text(time),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .decoration
        as ShapeDecoration;

void main() {
  final now = _at(18, 0);

  for (final brightness in Brightness.values) {
    group('in $brightness', () {
      final scheme = schemeOf(brightness);
      final colors = miserendColorsOf(brightness);

      testWidgets('the start stands in an occasionTimeContainer of its own '
          '(SZ4)', (tester) async {
        await pumpThemed(
          tester,
          MassStartHeader(mass: _mass(_at(18, 30)), now: now),
          brightness: brightness,
        );

        final container = _timeContainer(tester, '18:30');
        expect(container.color, colors.occasionTimeContainer);
        expect(
          container.shape,
          const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(Radii.s)),
          ),
        );
        expect(
          drawnStyle(tester, find.text('18:30')).color,
          colors.onOccasionTimeContainer,
        );
      });

      testWidgets('the time until start and the line are in the variant '
          'colours (SZ5)', (tester) async {
        await pumpThemed(
          tester,
          MassStartHeader(mass: _mass(_at(18, 25)), now: now),
          brightness: brightness,
        );

        expect(
          drawnStyle(tester, find.text('25 perc múlva')).color,
          scheme.onSurfaceVariant,
        );
        expect(
          tester.widget<Divider>(find.byType(Divider)).color,
          scheme.outlineVariant,
        );
      });

      testWidgets('an ongoing mass is marked by an „Épp most tart" badge, its '
          'start in the filled orange (KO6, SZ4)', (tester) async {
        await pumpThemed(
          tester,
          MassStartHeader(mass: _mass(_at(17, 55)), now: now),
          brightness: brightness,
        );

        expect(
          find.ancestor(
            of: find.text('Épp most tart'),
            matching: find.byType(StatusBadge),
          ),
          findsOneWidget,
        );
        expect(_timeContainer(tester, '17:55').color, colors.occasionTime);
        expect(
          drawnStyle(tester, find.text('17:55')).color,
          colors.onOccasionTime,
        );
      });
    });
  }

  testWidgets('the start is titleLarge w600 with tabular figures, the time '
      'until start labelMedium (TI2, TI4)', (tester) async {
    await pumpThemed(
      tester,
      MassStartHeader(mass: _mass(_at(18, 25)), now: now),
    );

    final textTheme =
        Theme.of(tester.element(find.byType(MassStartHeader))).textTheme;
    final start = drawnStyle(tester, find.text('18:25'));
    expect(start.fontSize, textTheme.titleLarge!.fontSize);
    expect(start.fontWeight, FontWeight.w600);
    expect(start.fontFeatures, contains(const FontFeature.tabularFigures()));
    expect(
      drawnStyle(tester, find.text('25 perc múlva')).fontSize,
      textTheme.labelMedium!.fontSize,
    );
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final width in eh4Widths) {
      for (final textScale in eh4TextScales) {
        for (final start in [_at(17, 55), _at(19, 5)]) {
          testWidgets('fits $width dp at text scale $textScale on $platform, '
              'starting ${start.hour}:${start.minute} (EH4)', (tester) async {
            await pumpThemed(
              tester,
              MassStartHeader(mass: _mass(start), now: now),
              platform: platform,
              width: width,
              textScale: textScale,
            );

            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  }
}
