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

/// The text of the tooltip on show with [message]: the tooltip writes it as a
/// rich text, unlike the plain text of the element it stands for.
Finder tooltipText(String message) => find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      widget.data == null &&
      widget.textSpan?.toPlainText() == message,
);

/// The visible box of the tooltip on show with [message], inside its margin
/// (DESIGN.md KO21).
Finder tooltipBox(String message) =>
    find
        .ancestor(of: tooltipText(message), matching: find.byType(DecoratedBox))
        .first;

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

/// The width of a screen that holds two columns of cards (DESIGN.md EL3).
const double twoColumnWidth = 1000;

/// The width of a screen wide enough for three columns of cards, which a
/// one-column page still keeps to [ContentWidth.maxWidth] (DESIGN.md EL3).
const double threeColumnWidth = 1300;

/// Checks that [content], on a screen [screenWidth] wide, takes the
/// [ContentWidth.maxWidth] the content is held to and stands in the middle.
void expectCentredContent(
  WidgetTester tester,
  Finder content, {
  double screenWidth = el3Width,
}) {
  final rect = tester.getRect(content);
  expect(rect.width, ContentWidth.maxWidth);
  expect(rect.center.dx, screenWidth / 2);
}

/// Checks the screen on show against the platforms' accessibility guidelines
/// (DESIGN.md AM1, AM3, AM5): tap targets of at least 48 × 48 on either
/// platform (the Android check is run on iOS too, and covers iOS's own 44), a
/// label on every tap target, and legible text.
Future<void> expectAccessibilityGuidelines(WidgetTester tester) async {
  final handle = tester.ensureSemantics();
  await tester.pump();
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  handle.dispose();
}
