import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/widgets/card_columns.dart';

/// A box [height] tall where it may choose, and as tall as it is made to be
/// otherwise — like a card in a row.
Widget _box(String key, double height) => ColoredBox(
  key: ValueKey(key),
  color: Colors.grey,
  child: SizedBox(height: height),
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 316, child: child),
      ),
    ),
  );
}

Rect _rect(WidgetTester tester, String key) =>
    tester.getRect(find.byKey(ValueKey(key)));

void main() {
  group('CardRow', () {
    testWidgets('makes every card as tall as the tallest', (tester) async {
      await _pump(
        tester,
        CardRow(
          columns: 3,
          gap: 8,
          children: [_box('a', 40), _box('b', 80), _box('c', 20)],
        ),
      );

      expect(_rect(tester, 'a'), const Rect.fromLTWH(0, 0, 100, 80));
      expect(_rect(tester, 'b'), const Rect.fromLTWH(108, 0, 100, 80));
      expect(_rect(tester, 'c'), const Rect.fromLTWH(216, 0, 100, 80));
    });

    testWidgets('a short last row keeps the columns\' width', (tester) async {
      await _pump(
        tester,
        CardRow(columns: 3, gap: 8, children: [_box('a', 40)]),
      );

      expect(_rect(tester, 'a'), const Rect.fromLTWH(0, 0, 100, 40));
    });
  });

  group('CardColumns', () {
    testWidgets('stands the columns side by side, from the top', (
      tester,
    ) async {
      await _pump(
        tester,
        CardColumns(gap: 16, columns: [_box('a', 100), _box('b', 60)]),
      );

      expect(_rect(tester, 'a'), const Rect.fromLTWH(0, 0, 150, 100));
      expect(_rect(tester, 'b'), const Rect.fromLTWH(166, 0, 150, 60));
      expect(tester.getSize(find.byType(CardColumns)).height, 100);
    });

    testWidgets('puts the tail under the shorter column', (tester) async {
      await _pump(
        tester,
        CardColumns(
          gap: 16,
          columns: [_box('a', 100), _box('b', 60)],
          tail: _box('tail', 70),
        ),
      );

      expect(_rect(tester, 'tail'), const Rect.fromLTWH(166, 60, 150, 70));
      expect(tester.getSize(find.byType(CardColumns)).height, 130);
    });

    testWidgets('of two equal columns, the tail goes under the first', (
      tester,
    ) async {
      await _pump(
        tester,
        CardColumns(
          gap: 16,
          columns: [_box('a', 60), _box('b', 60)],
          tail: _box('tail', 10),
        ),
      );

      expect(_rect(tester, 'tail'), const Rect.fromLTWH(0, 60, 150, 10));
    });
  });
}
