import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/theme/tokens.dart';
import 'package:miserend/widgets/time_chip.dart';

import '../theme/theme_harness.dart';

const _chipShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(Radii.s)),
);

/// The chip's surface.
Material _surface(WidgetTester tester) => tester.widget<Material>(
  find.descendant(of: find.byType(TimeChip), matching: find.byType(Material)),
);

void main() {
  const time = TimeOfDay(hour: 18, minute: 30);

  for (final brightness in Brightness.values) {
    group('in $brightness', () {
      final colors = miserendColorsOf(brightness);

      testWidgets('stands on occasionTimeContainer in its own colour (KO3)', (
        tester,
      ) async {
        await pumpThemed(
          tester,
          const TimeChip(time: time),
          brightness: brightness,
        );

        expect(_surface(tester).color, colors.occasionTimeContainer);
        expect(_surface(tester).shape, _chipShape);
        expect(
          drawnStyle(tester, find.text('18:30')).color,
          colors.onOccasionTimeContainer,
        );
      });

      testWidgets('an ongoing mass stands on occasionTime (KO3, SZ4)', (
        tester,
      ) async {
        await pumpThemed(
          tester,
          TimeChip(time: time, ongoing: true, hasInfo: true, onTap: () {}),
          brightness: brightness,
        );

        expect(_surface(tester).color, colors.occasionTime);
        expect(
          drawnStyle(tester, find.text('18:30')).color,
          colors.onOccasionTime,
        );
        expect(
          tester.widget<Icon>(find.byIcon(Icons.info_outline_rounded)).color,
          colors.onOccasionTime,
        );
      });

      testWidgets('the (i) marker is a rounded 18 icon in the text colour '
          '(IK1, IK3, IK4)', (tester) async {
        await pumpThemed(
          tester,
          TimeChip(time: time, hasInfo: true, onTap: () {}),
          brightness: brightness,
        );

        final icon = tester.widget<Icon>(
          find.byIcon(Icons.info_outline_rounded),
        );
        expect(icon.size, 18);
        expect(icon.color, colors.onOccasionTimeContainer);
      });
    });
  }

  testWidgets('the time is titleMedium w600 with tabular figures '
      '(KO3, TI3, TI4)', (tester) async {
    await pumpThemed(tester, const TimeChip(time: time));

    final style = drawnStyle(tester, find.text('18:30'));
    final textTheme = Theme.of(tester.element(find.byType(TimeChip))).textTheme;
    expect(style.fontSize, textTheme.titleMedium!.fontSize);
    expect(style.fontWeight, FontWeight.w600);
    expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
  });

  testWidgets('keeps 8 to the sides and 4 above and below its label (TK2)', (
    tester,
  ) async {
    await pumpThemed(tester, const TimeChip(time: time));

    final chip = tester.getRect(find.byType(TimeChip));
    final label = tester.getRect(find.text('18:30'));
    expect(label.left - chip.left, Spacing.s);
    expect(chip.right - label.right, Spacing.s);
    expect(label.top - chip.top, Spacing.xs);
    expect(chip.bottom - label.bottom, Spacing.xs);
  });

  testWidgets('a chip without onTap has no ink (KO4)', (tester) async {
    await pumpThemed(tester, const TimeChip(time: time));

    expect(
      find.descendant(
        of: find.byType(TimeChip),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
  });

  testWidgets('a chip with onTap responds to a tap', (tester) async {
    var taps = 0;
    await pumpThemed(
      tester,
      TimeChip(time: time, hasInfo: true, onTap: () => taps++),
    );

    await tester.tap(find.byType(TimeChip));

    expect(taps, 1);
  });

  testWidgets('widthOf is the width the chip is drawn at', (tester) async {
    for (final textScale in eh4TextScales) {
      await pumpThemed(
        tester,
        const Row(children: [TimeChip(time: time), TimeChip.more()]),
        textScale: textScale,
      );
      final context = tester.element(find.byType(Row));

      expect(
        TimeChip.widthOf(context, '18:30'),
        moreOrLessEquals(tester.getSize(find.byType(TimeChip).first).width),
      );
      expect(
        TimeChip.widthOf(context, TimeChip.moreLabel),
        moreOrLessEquals(tester.getSize(find.byType(TimeChip).last).width),
      );
    }
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final width in eh4Widths) {
      for (final textScale in eh4TextScales) {
        testWidgets('fits $width dp at text scale $textScale on $platform '
            '(EH4)', (tester) async {
          await pumpThemed(
            tester,
            Wrap(
              children: [
                TimeChip(time: time, hasInfo: true, onTap: () {}),
                const TimeChip(time: time, ongoing: true),
                const TimeChip.more(),
              ],
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
