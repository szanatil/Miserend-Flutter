import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/church_details/widgets/church_info_tiles.dart';
import 'package:miserend/theme/miserend_theme.dart';
import 'package:miserend/theme/tokens.dart';
import 'package:miserend/widgets/language_flag.dart';

import '../../theme/theme_harness.dart';

/// What is seen of the chip of a code with no flag: inside it, the chip pads
/// itself out to a tap target.
Finder _chipSurface() =>
    find.descendant(of: find.byType(Chip), matching: find.byType(Material));

/// The visible flag of [code].
Finder _flag(String code) => find.byWidgetPredicate(
  (widget) => widget is LanguageFlag && widget.code == code,
);

void main() {
  /// Pumps the tile for [languages] on a screen [width] wide at [textScale],
  /// down a list with room over it, the way the church details
  /// page holds it: the tooltip is laid out over the screen.
  Future<void> pumpOnScreen(
    WidgetTester tester,
    List<String> languages, {
    double width = 430,
    double textScale = 1,
    TargetPlatform platform = TargetPlatform.android,
    Brightness brightness = Brightness.light,
  }) async {
    setScreen(tester, Size(width, 800), textScale: textScale);
    await tester.pumpWidget(
      MaterialApp(
        theme: miserendTheme(brightness, platform: platform),
        home: Scaffold(
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              const SizedBox(height: 300),
              LanguagesTile(languages: languages),
              // Room to scroll the tile to the top of the screen.
              const SizedBox(height: 800),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a tapped flag names its language above it, 4 off the flag', (
    tester,
  ) async {
    await pumpOnScreen(tester, ['va', 'de']);

    await tester.tap(_flag('va'));
    await tester.pump(const Duration(milliseconds: 200));

    final flag = tester.getRect(_flag('va'));
    final box = tester.getRect(tooltipBox('latin'));
    expect(box.bottom, moreOrLessEquals(flag.top - Spacing.xs));
  });

  testWidgets('a flag takes a tap anywhere in the 48 × 48 around it (AM3)', (
    tester,
  ) async {
    // The middle one: a corner of a flag in the card's corner falls outside
    // the card's rounded shape, which takes no tap.
    await pumpOnScreen(tester, ['va', 'de', 'en']);
    final centre = tester.getCenter(_flag('de'));
    // Just inside each corner of the 48 dp square.
    const reach = kMinInteractiveDimension / 2 - 1;

    for (final corner in [
      const Offset(-reach, -reach),
      const Offset(reach, -reach),
      const Offset(-reach, reach),
      const Offset(reach, reach),
    ]) {
      await tester.tapAt(centre + corner);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tooltipText('német'), findsOneWidget, reason: '$corner');
      expect(tooltipText('latin'), findsNothing, reason: '$corner');
      expect(tooltipText('angol'), findsNothing, reason: '$corner');

      // Away, to dismiss it.
      await tester.tapAt(const Offset(1, 1));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('the flags stand 24 apart and 30 between rows, lined up with '
      'the title and inside the card as any content is', (tester) async {
    await pumpOnScreen(tester, _allSampled);

    final title = tester.getRect(find.text('Nyelvek'));
    final card = tester.getRect(
      find
          .descendant(of: find.byType(Card), matching: find.byType(Material))
          .first,
    );
    final flags = [for (final code in _allSampled) tester.getRect(_flag(code))];
    final rows = <double>{for (final flag in flags) flag.top}.toList()..sort();
    expect(rows.length, greaterThan(1));

    expect(flags.first.left, title.left);
    expect(flags.first.top - title.bottom, Spacing.s);
    expect(card.bottom - flags.last.bottom, Spacing.l);
    for (var i = 1; i < flags.length; i++) {
      if (flags[i].top == flags[i - 1].top) {
        expect(flags[i].left - flags[i - 1].right, 24, reason: _allSampled[i]);
      } else {
        expect(flags[i].left, title.left, reason: _allSampled[i]);
      }
    }
    for (var i = 1; i < rows.length; i++) {
      expect(rows[i] - (rows[i - 1] + LanguageFlag.height), 30);
    }
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final brightness in Brightness.values) {
      for (final width in eh4Widths) {
        for (final textScale in eh4TextScales) {
          testWidgets('a second row\'s flag names its language above it, 4 '
              'off the flag, 16 off the screen edges, at $width dp and text '
              'scale $textScale on $platform in $brightness (EH3–EH4)', (
            tester,
          ) async {
            await pumpOnScreen(
              tester,
              _allSampled,
              width: width,
              textScale: textScale,
              platform: platform,
              brightness: brightness,
            );
            expect(tester.takeException(), isNull);
            final firstRow = tester.getRect(_flag(_allSampled.first)).top;
            final code = _allSampled.lastWhere(
              (code) => tester.getRect(_flag(code)).top > firstRow,
            );
            final name = languageName(code);

            await tester.tap(_flag(code));
            await tester.pump(const Duration(milliseconds: 200));

            expect(tester.takeException(), isNull);
            final flag = tester.getRect(_flag(code));
            final box = tester.getRect(tooltipBox(name));
            expect(box.bottom, moreOrLessEquals(flag.top - Spacing.xs));
            expect(box.left, greaterThanOrEqualTo(Spacing.l));
            expect(box.right, lessThanOrEqualTo(width - Spacing.l));
          });
        }
      }
    }
  }

  testWidgets('with no room above, a flag names its language below it, 4 '
      'off the flag', (tester) async {
    await pumpOnScreen(tester, ['va', 'de']);
    // The flag a hair under the top of the screen.
    tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position
        .jumpTo(tester.getRect(_flag('va')).top - 2);
    await tester.pump();

    await tester.tap(_flag('va'));
    await tester.pump(const Duration(milliseconds: 200));

    final flag = tester.getRect(_flag('va'));
    final box = tester.getRect(tooltipBox('latin'));
    expect(box.top, moreOrLessEquals(flag.bottom + Spacing.xs));
  });

  testWidgets('a code with no flag shows no tooltip, and stands 24 off the '
      'flags, in the middle of their row', (tester) async {
    await pumpOnScreen(tester, ['va', 'zz', 'de']);
    final chip = find.byType(Chip);

    final va = tester.getRect(_flag('va'));
    final zz = tester.getRect(_chipSurface());
    final de = tester.getRect(_flag('de'));
    expect(zz.left - va.right, 24);
    expect(de.left - zz.right, 24);
    expect(zz.center.dy, va.center.dy);

    await tester.tap(chip);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(Tooltip), findsNWidgets(2));
    expect(tooltipText('ZZ'), findsNothing);
    expect(tooltipText('zz'), findsNothing);
  });

  testWidgets('tapping another flag swaps one name for the other', (
    tester,
  ) async {
    await pumpOnScreen(tester, ['va', 'de']);

    await tester.tap(_flag('va'));
    await tester.pump(const Duration(seconds: 1));
    expect(tooltipText('latin'), findsOneWidget);

    await tester.tap(_flag('de'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(tooltipText('latin'), findsNothing);
    expect(tooltipText('német'), findsOneWidget);
  });

  testWidgets('goes after 10 s', (tester) async {
    await pumpOnScreen(tester, ['va', 'de']);

    await tester.tap(_flag('va'));
    await tester.pump(const Duration(milliseconds: 9900));
    expect(tooltipText('latin'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(tooltipText('latin'), findsNothing);
  });

  testWidgets('tapped again, starts its 10 s over', (tester) async {
    await pumpOnScreen(tester, ['va', 'de']);

    await tester.tap(_flag('va'));
    await tester.pump(const Duration(seconds: 8));
    await tester.tap(_flag('va'));
    await tester.pump(const Duration(seconds: 8));
    expect(tooltipText('latin'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(tooltipText('latin'), findsNothing);
  });

  testWidgets('goes on a scroll', (tester) async {
    await pumpOnScreen(tester, ['va', 'de']);

    await tester.tap(_flag('va'));
    await tester.pump(const Duration(seconds: 1));
    expect(tooltipText('latin'), findsOneWidget);

    await tester.dragFrom(const Offset(200, 100), const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(tooltipText('latin'), findsNothing);
  });

  testWidgets('each language is read out once, by name, and is not a button '
      '(AM5)', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpOnScreen(tester, ['va', 'de', 'zz']);

    expect(find.bySemanticsLabel('latin'), findsOneWidget);
    expect(find.bySemanticsLabel('német'), findsOneWidget);
    expect(find.bySemanticsLabel('ZZ'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('latin')),
      isSemantics(label: 'latin', isImage: true, hasTapAction: false),
    );

    await tester.tap(_flag('va'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.bySemanticsLabel('latin'), findsOneWidget);
    handle.dispose();
  });

  for (final textScale in eh4TextScales) {
    testWidgets('a code with no flag stands as far in the card as a flag, at '
        'text scale $textScale', (tester) async {
      await pumpOnScreen(tester, ['zz'], textScale: textScale);

      final title = tester.getRect(find.text('Nyelvek'));
      final chip = tester.getRect(_chipSurface());
      final card = tester.getRect(
        find
            .descendant(of: find.byType(Card), matching: find.byType(Material))
            .first,
      );
      expect(chip.left, title.left);
      expect(chip.top - title.bottom, Spacing.s);
      expect(card.bottom - chip.bottom, Spacing.l);
    });
  }

  testWidgets('neighbouring tap areas meet halfway, across and between rows, '
      'and do not overlap (AM3)', (tester) async {
    await pumpOnScreen(tester, _allSampled, width: 320);
    final rects = {
      for (final code in _allSampled) code: tester.getRect(_flag(code)),
    };
    final upper = _allSampled[1];
    final right = _allSampled[2];
    final below =
        rects.entries
            .firstWhere(
              (entry) =>
                  entry.value.left == rects[upper]!.left &&
                  entry.value.top > rects[upper]!.bottom,
            )
            .key;

    Future<void> expectNameAt(Offset at, String code) async {
      await tester.tapAt(at);
      await tester.pump(const Duration(milliseconds: 200));
      for (final other in _allSampled) {
        expect(
          tooltipText(languageName(other)),
          other == code ? findsOneWidget : findsNothing,
          reason: '$at: $other',
        );
      }
      await tester.tapAt(const Offset(1, 1));
      await tester.pumpAndSettle();
    }

    final across = rects[upper]!.centerRight.dx;
    final y = rects[upper]!.center.dy;
    // The 24 between two flags: 12 to each.
    await expectNameAt(Offset(across + 11, y), upper);
    await expectNameAt(Offset(rects[right]!.left - 11, y), right);
    // The 30 between two rows: 15 to each.
    final x = rects[upper]!.center.dx;
    await expectNameAt(Offset(x, rects[upper]!.bottom + 14), upper);
    await expectNameAt(Offset(x, rects[below]!.top - 14), below);
  });
}

/// Every code found in a sample of 500 churches, all on one church (CONTEXT.md,
/// „Liturgikus nyelv jelölése").
const List<String> _allSampled = [
  'hu', 'va', 'en', 'de', 'fr', 'es', 'it', 'pl', 'sk', 'hr', 'ua', 'tl', //
];
