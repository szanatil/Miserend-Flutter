import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/widgets/content_width.dart';

import '../theme/theme_harness.dart';

void main() {
  const base = EdgeInsets.fromLTRB(16, 8, 16, 4);

  group('widen', () {
    test('leaves the padding alone on a phone', () {
      expect(ContentWidth.widen(base, 430), base);
    });

    test('leaves the padding alone where the content is just 640 wide', () {
      expect(ContentWidth.widen(base, 672), base);
    });

    test('centres 640 of content on a wider screen', () {
      expect(
        ContentWidth.widen(base, 800),
        const EdgeInsets.fromLTRB(80, 8, 80, 4),
      );
    });
  });

  group('columnsFor (EL3)', () {
    for (final (width, columns) in const [
      (320.0, 1),
      (839.0, 1),
      (840.0, 2),
      (1199.0, 2),
      (1200.0, 3),
      (2400.0, 3),
    ]) {
      test('$width dp wide is $columns column(s)', () {
        expect(ContentWidth.columnsFor(width), columns);
      });
    }
  });

  group('widen for columns', () {
    test('two columns at 840 dp share the whole width', () {
      expect(ContentWidth.widen(base, 840, columns: 2, gap: 8), base);
    });

    test('three columns on a very wide screen are 640 each, centred', () {
      final padding = ContentWidth.widen(base, 2400, columns: 3, gap: 8);

      expect(2400 - padding.horizontal, 3 * 640 + 2 * 8);
      expect(padding.left, padding.right);
      expect(padding.top, base.top);
      expect(padding.bottom, base.bottom);
    });
  });

  testWidgets('ContentColumns hands its builder the width\'s columns and '
      'their padding', (tester) async {
    setScreen(tester, const Size(1300, 600));
    late int columns;
    late EdgeInsets padding;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContentColumns(
            padding: base,
            gap: 8,
            builder: (context, p, c) {
              padding = p;
              columns = c;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );

    expect(columns, 3);
    expect(padding, ContentWidth.widen(base, 1300, columns: 3, gap: 8));
  });

  testWidgets('a list on an 800 dp screen is 640 wide and centred (EL3)', (
    tester,
  ) async {
    setScreen(tester, const Size(el3Width, 600));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContentWidth(
            builder:
                (context, padding) => ListView(
                  padding: padding,
                  children: const [SizedBox(height: 40, child: Text('Sor'))],
                ),
          ),
        ),
      ),
    );

    expectCentredContent(tester, find.byType(SizedBox).last);
  });
}
