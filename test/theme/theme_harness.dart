import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/theme/miserend_colors.dart';
import 'package:miserend/theme/miserend_theme.dart';
import 'package:miserend/widgets/content_width.dart';

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
      theme: miserendTheme(brightness, platform: platform),
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

/// The platforms every screen and card is checked on for size (DESIGN.md
/// EH4); the app's theme follows the platform the variant sets.
final TargetPlatformVariant eh4Platforms = TargetPlatformVariant(const {
  TargetPlatform.android,
  TargetPlatform.iOS,
});

/// Makes the test's screen [size] in dp, at [textScale], until the test ends.
void setScreen(WidgetTester tester, Size size, {double textScale = 1}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// The width of a wide screen, a tablet or a phone on its side, that the
/// content is checked to stay [ContentWidth.maxWidth] in (DESIGN.md EL3).
const double el3Width = 800;

/// Checks that [content], on a screen [el3Width] wide, takes the
/// [ContentWidth.maxWidth] the content is held to and stands in the middle.
void expectCentredContent(WidgetTester tester, Finder content) {
  final rect = tester.getRect(content);
  expect(rect.width, ContentWidth.maxWidth);
  expect(rect.center.dx, el3Width / 2);
}
