import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/widgets/status_badge.dart';

import '../theme/theme_harness.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('a filled occasionTime pill in $brightness (KO6)', (
      tester,
    ) async {
      final colors = miserendColorsOf(brightness);
      await pumpThemed(
        tester,
        const Align(
          alignment: Alignment.topLeft,
          child: StatusBadge(label: 'Épp most tart'),
        ),
        brightness: brightness,
      );

      final surface = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(StatusBadge),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = surface.decoration as ShapeDecoration;
      expect(decoration.color, colors.occasionTime);
      expect(decoration.shape, isA<StadiumBorder>());
      expect(
        drawnStyle(tester, find.text('Épp most tart')).color,
        colors.onOccasionTime,
      );
    });
  }

  testWidgets('its label is labelSmall (KO6, TI2)', (tester) async {
    await pumpThemed(tester, const StatusBadge(label: 'Épp most tart'));

    final textTheme =
        Theme.of(tester.element(find.byType(StatusBadge))).textTheme;
    expect(
      drawnStyle(tester, find.text('Épp most tart')).fontSize,
      textTheme.labelSmall!.fontSize,
    );
  });

  testWidgets('reads out as its label and is not tappable (KO6, AM5)', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpThemed(tester, const StatusBadge(label: 'Épp most tart'));

    expect(find.bySemanticsLabel('Épp most tart'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(StatusBadge),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
    semantics.dispose();
  });
}
