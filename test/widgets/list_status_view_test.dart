import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/theme/miserend_theme.dart';
import 'package:miserend/theme/tokens.dart';
import 'package:miserend/widgets/list_status_view.dart';

import '../theme/theme_harness.dart';

/// The list's status views (DESIGN.md KO8): their elements stand `Spacing.l`
/// apart, and they fit a narrow screen at a large text size (EH4), in either
/// mode (EH3).
void main() {
  Future<void> pumpView(
    WidgetTester tester,
    Widget view, {
    Brightness brightness = Brightness.light,
    double width = 400,
    double textScale = 1,
  }) async {
    setScreen(tester, Size(width, 800), textScale: textScale);

    await tester.pumpWidget(
      MaterialApp(theme: miserendTheme(brightness), home: Scaffold(body: view)),
    );
  }

  final views = <String, Widget Function()>{
    'loading': () => const LoadingView(message: 'Templomok betöltése…'),
    'message': () => const MessageView(message: 'Nincs kedvenc templomod.'),
  };

  testWidgets('the loading spinner and its caption stand Spacing.l apart '
      '(KO8)', (tester) async {
    await pumpView(tester, views['loading']!());

    final spinner = tester.getRect(find.byType(CircularProgressIndicator));
    final caption = tester.getRect(find.text('Templomok betöltése…'));
    expect(caption.top - spinner.bottom, Spacing.l);
  });

  group('fits (EH3, EH4)', () {
    for (final MapEntry(key: name, value: view) in views.entries) {
      for (final brightness in Brightness.values) {
        for (final width in eh4Widths) {
          for (final textScale in eh4TextScales) {
            testWidgets('$name in ${brightness.name} mode at $width dp and '
                'text scale $textScale', (tester) async {
              await pumpView(
                tester,
                view(),
                brightness: brightness,
                width: width,
                textScale: textScale,
              );

              expect(tester.takeException(), isNull);
            }, variant: eh4Platforms);
          }
        }
      }
    }
  });

  testWidgets(
    'the loading spinner is the platform\'s own (KO8, PL2)',
    (tester) async {
      await pumpView(tester, views['loading']!());

      expect(
        find.byType(CupertinoActivityIndicator),
        defaultTargetPlatform == TargetPlatform.iOS
            ? findsOneWidget
            : findsNothing,
      );
    },
    variant: TargetPlatformVariant(const {
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );
}
