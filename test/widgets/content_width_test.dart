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
