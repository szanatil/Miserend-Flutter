import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/splash.dart';
import 'package:miserend/theme/miserend_theme.dart';

import 'theme/theme_harness.dart';

/// A device whose export is downloaded and current; only the bootstrap
/// import's outcome varies.
class _FakeStartup extends AppStartup {
  _FakeStartup({required this.bootstrapped, required this.importSucceeds});

  bool bootstrapped;
  List<bool> importSucceeds;
  int imports = 0;

  @override
  Future<bool> exportExists() async => true;

  @override
  Future<bool> exportVersionCompatible() async => true;

  @override
  Future<bool> downloadExport() async => true;

  @override
  Future<bool> isCacheBootstrapped() async => bootstrapped;

  @override
  Future<void> bootstrapCache() async {
    final succeeds =
        importSucceeds[imports.clamp(0, importSucceeds.length - 1)];
    imports++;
    if (!succeeds) throw StateError('import failed');
    bootstrapped = true;
  }
}

/// Answers whether the cache is filled only when the test says so.
class _SlowStartup extends _FakeStartup {
  _SlowStartup() : super(bootstrapped: false, importSucceeds: [true]);

  final Completer<bool> answer = Completer();

  @override
  Future<bool> isCacheBootstrapped() => answer.future;
}

/// A device without a usable export: missing, or of the wrong version.
class _NoExportStartup extends _FakeStartup {
  _NoExportStartup({required this.exists})
    : super(bootstrapped: true, importSucceeds: [true]);

  final bool exists;
  int downloads = 0;

  /// Once downloaded the export is there; the splash checks its version only
  /// before the download, so it stays "incompatible" without harm.
  @override
  Future<bool> exportExists() async => exists || downloads > 0;

  @override
  Future<bool> exportVersionCompatible() async => false;

  @override
  Future<bool> downloadExport() async {
    downloads++;
    return true;
  }
}

void main() {
  Future<void> pumpSplash(WidgetTester tester, AppStartup startup) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RouteSplash(
          startup: startup,
          homeBuilder: (_) => const Scaffold(body: Text('Főképernyő')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('goes to the home screen once the cache has been filled', (
    tester,
  ) async {
    final startup = _FakeStartup(bootstrapped: true, importSucceeds: [true]);

    await pumpSplash(tester, startup);

    expect(find.text('Főképernyő'), findsOneWidget);
    expect(startup.imports, 0);
  });

  testWidgets('fills the cache on the first start, then goes on', (
    tester,
  ) async {
    final startup = _FakeStartup(bootstrapped: false, importSucceeds: [true]);

    await pumpSplash(tester, startup);

    expect(startup.imports, 1);
    expect(find.text('Főképernyő'), findsOneWidget);
  });

  testWidgets('a failed first import stops on an error with a retry, rather '
      'than going on to empty lists', (tester) async {
    final startup = _FakeStartup(
      bootstrapped: false,
      importSucceeds: [false, true],
    );

    await pumpSplash(tester, startup);

    expect(find.text('Főképernyő'), findsNothing);
    expect(
      find.text('Az adatok előkészítése nem sikerült. Próbáld újra.'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Újrapróbálás'));
    await tester.pumpAndSettle();

    expect(startup.imports, 2);
    expect(find.text('Főképernyő'), findsOneWidget);
  });

  testWidgets('a splash gone before the cache check answers starts no import', (
    tester,
  ) async {
    final startup = _SlowStartup();
    await tester.pumpWidget(
      MaterialApp(
        home: RouteSplash(
          startup: startup,
          homeBuilder: (_) => const Scaffold(body: Text('Főképernyő')),
        ),
      ),
    );
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    startup.answer.complete(false);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(startup.imports, 0);
  });

  const askToDownload =
      'Az app használatához egyszer le kell tölteni a templomok és misék '
      'adatait. Letöltöd most?';

  /// Pumps the splash up to its download dialog. The spinner behind the
  /// dialog never settles, so it pumps fixed frames instead.
  Future<void> pumpDialog(
    WidgetTester tester,
    AppStartup startup, {
    Brightness brightness = Brightness.light,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: miserendTheme(brightness),
        home: RouteSplash(
          startup: startup,
          homeBuilder: (_) => const Scaffold(body: Text('Főképernyő')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  for (final brightness in Brightness.values) {
    for (final (exists, title) in [
      (false, 'Hiányoznak a miserendek'),
      (true, 'Elavultak a miserendek'),
    ]) {
      testWidgets('asks to download, in the second person, when the export is '
          '${exists ? 'out of date' : 'missing'}, in $brightness (SV1, SV3, '
          'SV4)', (tester) async {
        final startup = _NoExportStartup(exists: exists);
        await pumpDialog(tester, startup, brightness: brightness);

        expect(find.text(title), findsOneWidget);
        expect(find.text(askToDownload), findsOneWidget);
        expect(find.text('Kilépés'), findsOneWidget);
        expect(find.text('Letöltés'), findsOneWidget);

        await tester.tap(find.text('Letöltés'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(startup.downloads, 1);
        expect(find.text('A miserendek letöltése sikeres'), findsOneWidget);
        expect(find.text('Főképernyő'), findsOneWidget);
      }, variant: eh4Platforms);
    }
  }

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
    void sizeView(WidgetTester tester, double width, double textScale) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }

    for (final width in eh4Widths) {
      for (final textScale in eh4TextScales) {
        testWidgets('the error with its retry at $width dp and text scale '
            '$textScale', (tester) async {
          sizeView(tester, width, textScale);

          await pumpSplash(
            tester,
            _FakeStartup(bootstrapped: false, importSucceeds: [false]),
          );

          expect(find.text('Újrapróbálás'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });

        testWidgets(
          'the download dialog at $width dp and text scale $textScale',
          (tester) async {
            sizeView(tester, width, textScale);

            await pumpDialog(tester, _NoExportStartup(exists: false));

            expect(find.text('Letöltés'), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
          variant: eh4Platforms,
        );

        testWidgets('the spinner at $width dp and text scale $textScale', (
          tester,
        ) async {
          sizeView(tester, width, textScale);

          await tester.pumpWidget(
            MaterialApp(
              home: RouteSplash(
                startup: _SlowStartup(),
                homeBuilder: (_) => const Scaffold(body: Text('Főképernyő')),
              ),
            ),
          );
          await tester.pump();

          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(tester.takeException(), isNull);
          // Gone before the check answers, so nothing is left running.
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  });
}
