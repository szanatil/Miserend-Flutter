import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/bootstrap/bootstrap_progress_page.dart';
import 'package:miserend/bootstrap/cache_bootstrap.dart';
import 'package:miserend/splash.dart';
import 'package:miserend/theme/miserend_theme.dart';

import 'bootstrap/fake_cache_bootstrap.dart';
import 'theme/theme_harness.dart';

const _offer =
    'A jobb élményhez töltsd le egyszer a templomok és misék adatait '
    '(21,8 MB). Nélküle az app csak korlátozottan működik. A letöltést később '
    'a Névjegyen is elindíthatod.';

void main() {
  /// Starts the app on [bootstrap]. The spinner never settles, so it pumps
  /// fixed frames instead; [bootstrap] keeps its flags from an earlier start.
  Future<void> start(
    WidgetTester tester,
    FakeCacheBootstrap bootstrap, {
    Brightness brightness = Brightness.light,
  }) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        theme: miserendTheme(brightness, platform: defaultTargetPlatform),
        home: RouteSplash(
          bootstrap: bootstrap,
          homeBuilder: (_) => const Scaffold(body: Text('Főképernyő')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> choose(WidgetTester tester, String action) async {
    await tester.tap(find.text(action));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('goes on to the home screen without an offer when the size '
      'does not come back, and asks for it again on the next start', (
    tester,
  ) async {
    final bootstrap = FakeCacheBootstrap();

    await start(tester, bootstrap);

    expect(find.text(_offer, findRichText: true), findsNothing);
    expect(find.text('Főképernyő'), findsOneWidget);
    expect(bootstrap.runs, 0);

    await start(tester, bootstrap);
    expect(bootstrap.sizeQueries, 2);
  });

  for (final brightness in Brightness.values) {
    testWidgets('offers the download with its size, and says where to find it '
        'later, in $brightness (SV1, SV3)', (tester) async {
      await start(
        tester,
        FakeCacheBootstrap(size: 21800000),
        brightness: brightness,
      );

      expect(find.text('Templomok és misék letöltése'), findsOneWidget);
      expect(find.text(_offer), findsOneWidget);
      expect(find.text('Most nem'), findsOneWidget);
      expect(find.text('Letöltés'), findsOneWidget);
      expect(find.text('Kilépés'), findsNothing);
      expect(find.text('Főképernyő'), findsNothing);
    }, variant: eh4Platforms);
  }

  testWidgets('„Most nem" goes on without the download, and is not offered '
      'again', (tester) async {
    final bootstrap = FakeCacheBootstrap(size: 21800000);
    await start(tester, bootstrap);

    await choose(tester, 'Most nem');

    expect(find.text('Főképernyő'), findsOneWidget);
    expect(bootstrap.runs, 0);
    expect(bootstrap.declined, isTrue);

    await start(tester, bootstrap);
    expect(bootstrap.sizeQueries, 1);
    expect(find.text(_offer), findsNothing);
    expect(find.text('Főképernyő'), findsOneWidget);
  });

  testWidgets('„Letöltés" runs it on the progress screen, then goes on to '
      'the home screen', (tester) async {
    final bootstrap = FakeCacheBootstrap(size: 21800000);
    await start(tester, bootstrap);

    await choose(tester, 'Letöltés');

    expect(find.byType(BootstrapProgressPage), findsOneWidget);
    expect(bootstrap.runs, 1);

    bootstrap.report(const BootstrapImporting());
    await bootstrap.end(const BootstrapDone());
    await tester.pumpAndSettle();

    expect(find.text('Főképernyő'), findsOneWidget);
  });

  testWidgets('stopped with „Mégse", it goes on, and is not offered on the '
      'next start', (tester) async {
    final bootstrap = FakeCacheBootstrap(size: 21800000);
    await start(tester, bootstrap);
    await choose(tester, 'Letöltés');
    bootstrap.report(const BootstrapDownloading(100, 21800000));
    await tester.pump();

    await tester.tap(find.text('Mégse'));
    await bootstrap.end(const BootstrapCancelled());
    await tester.pumpAndSettle();

    expect(find.text('Főképernyő'), findsOneWidget);

    await start(tester, bootstrap);
    expect(find.text(_offer), findsNothing);
    expect(find.text('Főképernyő'), findsOneWidget);
  });

  testWidgets('a failed run goes on, and is offered again on the next start', (
    tester,
  ) async {
    final bootstrap = FakeCacheBootstrap(size: 21800000);
    await start(tester, bootstrap);
    await choose(tester, 'Letöltés');

    await bootstrap.end(const BootstrapFailed());
    await tester.pump();
    await tester.pump(BootstrapProgressPage.failureShown);
    await tester.pumpAndSettle();
    expect(find.text('Főképernyő'), findsOneWidget);

    await start(tester, bootstrap);
    expect(find.text(_offer), findsOneWidget);
  });

  testWidgets('once it has succeeded, neither the size nor the offer', (
    tester,
  ) async {
    final bootstrap = FakeCacheBootstrap(size: 21800000, done: true);

    await start(tester, bootstrap);

    expect(bootstrap.sizeQueries, 0);
    expect(find.text(_offer), findsNothing);
    expect(find.text('Főképernyő'), findsOneWidget);
  });

  testWidgets('a splash gone before the size comes back offers nothing', (
    tester,
  ) async {
    final bootstrap = FakeCacheBootstrap(size: 21800000)
      ..sizeHeld = Completer<void>();
    await start(tester, bootstrap);

    await tester.pumpWidget(const SizedBox.shrink());
    bootstrap.sizeHeld!.complete();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text(_offer), findsNothing);
  });

  test('the splash says neither „adatbázis” nor „Letölti” (SV1, SV4)', () {
    final source = File('lib/splash.dart').readAsStringSync();
    final strings = RegExp(
      r"'([^'\\]|\\.)*'"
      r'|"([^"\\]|\\.)*"',
    ).allMatches(source).map((m) => m[0]!.toLowerCase());

    expect(strings.where((s) => s.contains('adatbázis')), isEmpty);
    expect(strings.where((s) => s.contains('letölti')), isEmpty);
  });

  group('fits (EH4)', () {
    for (final width in eh4Widths) {
      for (final textScale in eh4TextScales) {
        testWidgets('the offer at $width dp and text scale $textScale', (
          tester,
        ) async {
          setScreen(tester, Size(width, 800), textScale: textScale);

          await start(tester, FakeCacheBootstrap(size: 21800000));

          expect(find.text('Letöltés'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }, variant: eh4Platforms);

        testWidgets('the spinner at $width dp and text scale $textScale', (
          tester,
        ) async {
          setScreen(tester, Size(width, 800), textScale: textScale);
          final bootstrap = FakeCacheBootstrap(size: 21800000)
            ..sizeHeld = Completer<void>();

          await start(tester, bootstrap);

          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          bootstrap.sizeHeld!.complete();
        }, variant: eh4Platforms);
      }
    }
  });
}
