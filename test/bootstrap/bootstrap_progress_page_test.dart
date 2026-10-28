import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/bootstrap/bootstrap_progress_page.dart';
import 'package:miserend/bootstrap/cache_bootstrap.dart';
import 'package:miserend/theme/miserend_theme.dart';
import 'package:miserend/theme/tokens.dart';
import 'package:miserend/widgets/list_status_view.dart';

import '../theme/theme_harness.dart';
import 'fake_cache_bootstrap.dart';

void main() {
  /// A page that opens the progress screen, so that it can be seen to close.
  Future<FakeCacheBootstrap> pumpOpened(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
  }) async {
    final bootstrap = FakeCacheBootstrap();
    await tester.pumpWidget(
      MaterialApp(
        theme: miserendTheme(brightness, platform: defaultTargetPlatform),
        home: Scaffold(
          body: Builder(
            builder:
                (context) => TextButton(
                  onPressed:
                      () => BootstrapProgressPage.open(context, bootstrap),
                  child: const Text('Névjegy'),
                ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Névjegy'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    return bootstrap;
  }

  testWidgets('shows the two steps, the download in megabytes', (tester) async {
    final bootstrap = await pumpOpened(tester);

    bootstrap.report(const BootstrapDownloading(8400000, 21800000));
    await tester.pump();

    expect(find.text('Letöltés'), findsOneWidget);
    expect(find.text('8,4 / 21,8 MB'), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      closeTo(8.4 / 21.8, 0.001),
    );
  });

  testWidgets('says the megabytes under the bar, Spacing.l from the edge '
      '(DESIGN.md KO8)', (tester) async {
    setScreen(tester, const Size(320, 640));
    final bootstrap = await pumpOpened(tester);

    bootstrap.report(const BootstrapDownloading(8400000, 21800000));
    await tester.pump();

    final progress = find.byType(LoadingProgress);
    expect(
      find.descendant(of: progress, matching: find.text('8,4 / 21,8 MB')),
      findsOneWidget,
    );
    final bar = tester.getRect(find.byType(LinearProgressIndicator));
    expect(bar.left, Spacing.l);
    expect(bar.right, 320 - Spacing.l);
  });

  testWidgets('says „kb. 22 MB" while the size is not known', (tester) async {
    final bootstrap = await pumpOpened(tester);

    bootstrap.report(const BootstrapDownloading(1000000, null));
    await tester.pump();

    expect(find.text('1,0 / kb. 22 MB'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(
      find.descendant(
        of: find.byType(LoadingProgress),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
  });

  testWidgets('marks the finished download with the outline check '
      '(DESIGN.md IK2)', (tester) async {
    final bootstrap = await pumpOpened(tester);

    bootstrap.report(const BootstrapImporting());
    await tester.pump();

    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
  });

  testWidgets('stops the download with „Mégse", and closes once stopped', (
    tester,
  ) async {
    final bootstrap = await pumpOpened(tester);
    bootstrap.report(const BootstrapDownloading(100, 21800000));
    await tester.pump();

    await tester.tap(find.text('Mégse'));
    expect(bootstrap.cancels, 1);

    await bootstrap.end(const BootstrapCancelled());
    await tester.pumpAndSettle();
    expect(find.byType(BootstrapProgressPage), findsNothing);
    expect(find.text('Névjegy'), findsOneWidget);
  });

  testWidgets('offers no „Mégse" during the import', (tester) async {
    final bootstrap = await pumpOpened(tester);
    bootstrap.report(const BootstrapDownloading(21800000, 21800000));
    bootstrap.report(const BootstrapImporting());
    await tester.pump();

    expect(find.text('Mégse'), findsNothing);
    expect(find.text('21,8 / 21,8 MB'), findsOneWidget);
  });

  testWidgets('closes when done', (tester) async {
    final bootstrap = await pumpOpened(tester);
    bootstrap.report(const BootstrapImporting());

    await bootstrap.end(const BootstrapDone());
    await tester.pumpAndSettle();

    expect(find.byType(BootstrapProgressPage), findsNothing);
  });

  testWidgets('says a failure, then closes', (tester) async {
    final bootstrap = await pumpOpened(tester);

    await bootstrap.end(const BootstrapFailed());
    await tester.pump();

    expect(
      find.text(
        'A letöltés nem sikerült. Később újra megpróbálhatod a Névjegyen.',
      ),
      findsOneWidget,
    );
    expect(find.text('Mégse'), findsNothing);

    await tester.pump(BootstrapProgressPage.failureShown);
    await tester.pumpAndSettle();
    expect(find.byType(BootstrapProgressPage), findsNothing);
  });

  testWidgets('back does not leave it while the download runs', (tester) async {
    await pumpOpened(tester);

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.byType(BootstrapProgressPage), findsOneWidget);
  });

  group('fits (EH3, EH4)', () {
    for (final brightness in Brightness.values) {
      for (final width in eh4Widths) {
        for (final textScale in eh4TextScales) {
          testWidgets('at $width dp, text scale $textScale, in $brightness', (
            tester,
          ) async {
            setScreen(tester, Size(width, 640), textScale: textScale);
            final bootstrap = await pumpOpened(tester, brightness: brightness);

            bootstrap.report(const BootstrapDownloading(21800000, 21800000));
            await tester.pump();
            expect(find.text('Mégse'), findsOneWidget);
            expect(tester.takeException(), isNull);

            await bootstrap.end(const BootstrapFailed());
            await tester.pump();
            expect(tester.takeException(), isNull);
            await tester.pump(BootstrapProgressPage.failureShown);
            await tester.pumpAndSettle();
          }, variant: eh4Platforms);
        }
      }
    }
  });
}
