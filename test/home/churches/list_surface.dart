import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/theme/miserend_theme.dart';

/// Checks that a church list stands on the page's own `surface` in
/// [brightness], with no colour of its own behind it (DESIGN.md SZ5, MÉ1).
void expectListOnSurface(WidgetTester tester, Brightness brightness) {
  final ground = tester.widget<Material>(
    find
        .descendant(of: find.byType(Scaffold), matching: find.byType(Material))
        .first,
  );
  expect(ground.color, miserendTheme(brightness).colorScheme.surface);
  expect(
    find.ancestor(
      of: find.byType(Scrollable).first,
      matching: find.byWidgetPredicate(
        (w) =>
            (w is Container && w.color != null) ||
            (w is ColoredBox && w.color != Colors.transparent),
      ),
    ),
    findsNothing,
  );
}
