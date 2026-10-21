import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/location_provider.dart';
import 'package:miserend/theme/miserend_theme.dart';
import 'package:miserend/theme/tokens.dart';
import 'package:miserend/widgets/position_unavailable_view.dart';

import '../fake_location_provider.dart';
import '../theme/theme_harness.dart';

/// The **Helyzet nem elérhető** view as a status view (DESIGN.md KO8): its
/// message and button stand `Spacing.l` apart, and it fits a narrow screen at
/// a large text size (EH4), in either mode (EH3).
void main() {
  Future<void> pumpView(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    double width = 400,
    double textScale = 1,
  }) async {
    setScreen(tester, Size(width, 800), textScale: textScale);

    await tester.pumpWidget(
      MaterialApp(
        theme: miserendTheme(brightness),
        home: Scaffold(
          body: PositionUnavailableView(
            reason: PositionUnavailableReason.permissionDeniedForever,
            purpose: 'A közeli templomokhoz',
            location: FakeLocationProvider(),
            onRetry: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('the message and its button stand Spacing.l apart (KO8)', (
    tester,
  ) async {
    await pumpView(tester);

    final message = tester.getRect(
      find.textContaining('engedélyezd a helyadatot'),
    );
    final button = tester.getRect(find.byType(FilledButton));
    expect(button.top - message.bottom, Spacing.l);
  });

  group('fits (EH3, EH4)', () {
    for (final brightness in Brightness.values) {
      for (final width in eh4Widths) {
        for (final textScale in eh4TextScales) {
          testWidgets('in ${brightness.name} mode at $width dp and text '
              'scale $textScale', (tester) async {
            await pumpView(
              tester,
              brightness: brightness,
              width: width,
              textScale: textScale,
            );

            expect(tester.takeException(), isNull);
          }, variant: eh4Platforms);
        }
      }
    }
  });
}
