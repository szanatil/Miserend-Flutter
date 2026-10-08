import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/theme/tokens.dart';
import 'package:miserend/widgets/section_card.dart';

import '../theme/theme_harness.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('is a theme card, raised 1, in $brightness (KO1, MÉ1)', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const SectionCard(title: 'Elérhetőség', child: Text('Tartalom')),
        brightness: brightness,
      );

      final surface = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(SectionCard),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(surface.color, schemeOf(brightness).surfaceContainerLow);
      expect(surface.elevation, 1);
      expect(
        surface.shape,
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(Radii.m)),
        ),
      );
    });
  }

  testWidgets('the title is a titleMedium w600 section title (TI2)', (
    tester,
  ) async {
    await pumpThemed(
      tester,
      const SectionCard(title: 'Elérhetőség', child: Text('Tartalom')),
    );

    final textTheme =
        Theme.of(tester.element(find.byType(SectionCard))).textTheme;
    final style = drawnStyle(tester, find.text('Elérhetőség'));
    expect(style.fontSize, textTheme.titleMedium!.fontSize);
    expect(style.fontWeight, FontWeight.w600);
  });

  testWidgets('stands 16 from the screen edge, 16 inside, 8 under the title '
      '(KO1, TK2)', (tester) async {
    await pumpThemed(
      tester,
      const SectionCard(title: 'Elérhetőség', child: Text('Tartalom')),
      width: 360,
    );

    final title = tester.getRect(find.text('Elérhetőség'));
    final content = tester.getRect(find.text('Tartalom'));
    expect(title.left, Spacing.l + Spacing.l);
    expect(content.top - title.bottom, Spacing.s);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final width in eh4Widths) {
      for (final textScale in eh4TextScales) {
        testWidgets('fits $width dp at text scale $textScale on $platform '
            '(EH4)', (tester) async {
          await pumpThemed(
            tester,
            SectionCard(
              title: 'Elérhetőség és megközelítés',
              trailing: IconButton(
                icon: const Icon(Icons.keyboard_arrow_up_rounded),
                onPressed: () {},
              ),
              child: const Text('Tartalom'),
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
