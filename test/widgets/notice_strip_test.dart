import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/api/api_result.dart';
import 'package:miserend/home/map/widgets/position_unavailable_banner.dart';
import 'package:miserend/location_provider.dart';
import 'package:miserend/theme/tokens.dart';
import 'package:miserend/widgets/notice_strip.dart';
import 'package:miserend/widgets/offline_notice.dart';

import '../fake_location_provider.dart';
import '../theme/theme_harness.dart';

/// Every strip the app shows with its line, by the name a test reads it
/// under.
final Map<String, (Widget, String)> _strips = {
  'no connection': (
    OfflineBanner(
      failure: ApiFailure.noConnection,
      asOf: null,
      onRetry: () async {},
    ),
    'Nincs kapcsolat, tárolt adatok',
  ),
  'server error': (
    OfflineBanner(
      failure: ApiFailure.serverError,
      asOf: null,
      onRetry: () async {},
    ),
    'A miserend.hu nem elérhető, tárolt adatok',
  ),
  'position unavailable': (
    PositionUnavailableBanner(
      reason: PositionUnavailableReason.permissionDenied,
      location: FakeLocationProvider(),
      onRetry: () {},
      onClose: () {},
    ),
    'A helyzeted mutatásához engedélyezd a helyadatot.',
  ),
};

/// The band the strip draws, edge to edge.
Rect _band(WidgetTester tester) => tester.getRect(
  find
      .descendant(of: find.byType(NoticeStrip), matching: find.byType(Material))
      .first,
);

/// The rectangles of the strip's widgets that match [test].
List<Rect> _rectsOf(WidgetTester tester, bool Function(Widget) test) =>
    tester
        .widgetList(
          find.descendant(
            of: find.byType(NoticeStrip),
            matching: find.byWidgetPredicate(test),
          ),
        )
        .map((widget) => tester.getRect(find.byWidget(widget)))
        .toList();

bool _isButton(Widget widget) =>
    widget is IconButton || widget is ButtonStyleButton;

/// The strip's buttons.
List<Rect> _buttons(WidgetTester tester) => _rectsOf(tester, _isButton);

/// The strip's icon, line and buttons.
List<Rect> _contents(WidgetTester tester) => _rectsOf(
  tester,
  (widget) => _isButton(widget) || widget is Icon || widget is Text,
);

void main() {
  testWidgets('a strip puts its buttons under the line, at the end, where '
      'they would take more than half of it (KO7, EL2)', (tester) async {
    final (strip, line) = _strips['position unavailable']!;
    await pumpThemed(tester, strip, width: 320, textScale: 2);

    final text = tester.getRect(find.text(line));
    final buttons = _buttons(tester);
    for (final button in buttons) {
      expect(button.top, greaterThanOrEqualTo(text.bottom));
    }
    expect(buttons.last.right, _band(tester).right - Spacing.l);
  });

  for (final MapEntry(key: name, value: (strip, line)) in _strips.entries) {
    group('the $name strip', () {
      for (final width in [...eh4Widths, 400.0]) {
        for (final textScale in eh4TextScales) {
          testWidgets('keeps its content l from the sides and s from the top '
              'and bottom at $width dp and text scale $textScale (KO7)', (
            tester,
          ) async {
            await pumpThemed(tester, strip, width: width, textScale: textScale);

            final band = _band(tester);
            final content = _contents(
              tester,
            ).reduce((a, b) => a.expandToInclude(b));

            expect(content.left - band.left, Spacing.l);
            expect(band.right - content.right, Spacing.l);
            expect(content.top - band.top, Spacing.s);
            expect(band.bottom - content.bottom, Spacing.s);
          });
        }
      }

      testWidgets('keeps its buttons beside the line where they take at most '
          'half the strip (KO7)', (tester) async {
        await pumpThemed(tester, strip, width: 800);

        final text = tester.getRect(find.text(line));
        for (final button in _buttons(tester)) {
          expect(button.left, greaterThanOrEqualTo(text.right));
          expect(button.center.dy, moreOrLessEquals(text.center.dy));
        }
      });

      for (final brightness in Brightness.values) {
        testWidgets('in $brightness, meets the accessibility guidelines '
            '(AM3)', (tester) async {
          await pumpThemed(tester, strip, brightness: brightness);

          await expectAccessibilityGuidelines(tester);
        });
      }

      group('fits (EH3, EH4)', () {
        for (final platform in eh4Platforms.values) {
          for (final brightness in Brightness.values) {
            for (final width in eh4Widths) {
              for (final textScale in eh4TextScales) {
                testWidgets('on $platform in $brightness at $width dp and '
                    'text scale $textScale', (tester) async {
                  await pumpThemed(
                    tester,
                    strip,
                    brightness: brightness,
                    platform: platform,
                    width: width,
                    textScale: textScale,
                  );

                  expect(find.byType(NoticeStrip), findsOneWidget);
                  expect(tester.takeException(), isNull);
                });
              }
            }
          }
        }
      });
    });
  }
}
