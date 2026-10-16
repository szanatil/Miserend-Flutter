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

  testWidgets('content may reach into the padding and over the title by '
      'its bleed, and takes taps there', (tester) async {
    var taps = 0;
    await pumpThemed(
      tester,
      SectionCard(
        title: 'Nyelvek',
        bleed: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => taps++,
          child: const SizedBox(height: 48),
        ),
      ),
      width: 360,
    );

    final title = tester.getRect(find.text('Nyelvek'));
    final card = tester.getRect(
      find
          .descendant(of: find.byType(Card), matching: find.byType(Material))
          .first,
    );
    final content = tester.getRect(find.byType(GestureDetector));
    expect(content.left, title.left - 12);
    expect(content.right, card.right - Spacing.l + 12);
    expect(content.top, title.bottom + Spacing.s - 15);
    expect(card.bottom - content.bottom, Spacing.l - 15);

    // Over the title, and in the padding at either side and below; not in
    // the card's corners, which its rounded shape keeps for itself.
    await tester.tapAt(content.topCenter + const Offset(0, 1));
    await tester.tapAt(content.centerLeft + const Offset(1, 0));
    await tester.tapAt(content.centerRight - const Offset(1, 0));
    await tester.tapAt(content.bottomCenter - const Offset(0, 1));
    expect(taps, 4);
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
