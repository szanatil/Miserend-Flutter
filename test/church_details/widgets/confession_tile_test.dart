import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/church_details/widgets/confession_tile.dart';
import 'package:miserend/widgets/status_badge.dart';

import '../../theme/theme_harness.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('a theme card with a „Most gyóntatnak" status badge, in '
        '$brightness (KO1, KO6, SZ4)', (tester) async {
      final scheme = schemeOf(brightness);
      await pumpThemed(tester, const ConfessionTile(), brightness: brightness);

      final card = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(ConfessionTile),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(card.color, scheme.surfaceContainerLow);
      expect(
        find.ancestor(
          of: find.text('Most gyóntatnak'),
          matching: find.byType(StatusBadge),
        ),
        findsOneWidget,
      );
      final icon = tester.widget<Icon>(
        find.byIcon(Icons.record_voice_over_rounded),
      );
      expect(icon.color, scheme.onSurfaceVariant);
    });
  }

  for (final width in eh4Widths) {
    for (final textScale in eh4TextScales) {
      testWidgets('fits $width dp at text scale $textScale (EH4)', (
        tester,
      ) async {
        await pumpThemed(
          tester,
          const ConfessionTile(),
          width: width,
          textScale: textScale,
        );

        expect(tester.takeException(), isNull);
      });
    }
  }
}
