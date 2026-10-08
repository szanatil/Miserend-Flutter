import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/theme/miserend_colors.dart';
import 'package:miserend/theme/miserend_theme.dart';

/// The screen widths and text scales every card and chip is checked at
/// (DESIGN.md EH4).
const List<double> eh4Widths = [320, 430];
const List<double> eh4TextScales = [1.0, 2.0];

/// Pumps [child] in the app's theme of [brightness] on [platform], in a
/// scrollable column [width] wide at [textScale], the way a list holds it.
Future<void> pumpThemed(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
  TargetPlatform platform = TargetPlatform.android,
  double width = 400,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: miserendTheme(brightness).copyWith(platform: platform),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: SingleChildScrollView(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: width, child: child),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The colour scheme of the app's theme in [brightness].
ColorScheme schemeOf(Brightness brightness) =>
    miserendTheme(brightness).colorScheme;

/// The app's own colour roles in [brightness].
MiserendColors miserendColorsOf(Brightness brightness) =>
    miserendTheme(brightness).extension<MiserendColors>()!;

/// The style [text] is drawn in, its inherited parts merged in.
TextStyle drawnStyle(WidgetTester tester, Finder text) {
  final widget = tester.widget<Text>(text);
  return DefaultTextStyle.of(tester.element(text)).style.merge(widget.style);
}
