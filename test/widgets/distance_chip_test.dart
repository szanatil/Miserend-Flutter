import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/theme/tokens.dart';
import 'package:miserend/widgets/distance_chip.dart';

import '../theme/theme_harness.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('stands on surfaceContainerHighest in onSurfaceVariant, '
        'in $brightness (KO4)', (tester) async {
      final scheme = schemeOf(brightness);
      await pumpThemed(
        tester,
        const DistanceChip(km: 1.23),
        brightness: brightness,
      );

      final surface = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(DistanceChip),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = surface.decoration as ShapeDecoration;
      expect(decoration.color, scheme.surfaceContainerHighest);
      expect(
        decoration.shape,
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(Radii.s)),
        ),
      );
      expect(
        drawnStyle(tester, find.text('1,2 km')).color,
        scheme.onSurfaceVariant,
      );
    });
  }

  testWidgets('the distance is labelLarge with tabular figures (KO4, TI4)', (
    tester,
  ) async {
    await pumpThemed(tester, const DistanceChip(km: 1.23));

    final style = drawnStyle(tester, find.text('1,2 km'));
    final textTheme =
        Theme.of(tester.element(find.byType(DistanceChip))).textTheme;
    expect(style.fontSize, textTheme.labelLarge!.fontSize);
    expect(style.fontWeight, textTheme.labelLarge!.fontWeight);
    expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
  });

  testWidgets('keeps 8 to the sides and 4 above and below its label (TK2)', (
    tester,
  ) async {
    await pumpThemed(
      tester,
      const Align(alignment: Alignment.topLeft, child: DistanceChip(km: 1.23)),
    );

    final chip = tester.getRect(find.byType(DistanceChip));
    final label = tester.getRect(find.text('1,2 km'));
    expect(label.left - chip.left, Spacing.s);
    expect(label.top - chip.top, Spacing.xs);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final width in eh4Widths) {
      for (final textScale in eh4TextScales) {
        testWidgets('fits $width dp at text scale $textScale on $platform '
            '(EH4)', (tester) async {
          await pumpThemed(
            tester,
            const Wrap(
              children: [DistanceChip(km: 0.85), DistanceChip(km: 123.4)],
            ),
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
