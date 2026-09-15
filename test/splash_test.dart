import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/splash.dart';

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
    final succeeds = importSucceeds[imports.clamp(0, importSucceeds.length - 1)];
    imports++;
    if (!succeeds) throw StateError('import failed');
    bootstrapped = true;
  }
}

void main() {
  Future<void> pumpSplash(WidgetTester tester, AppStartup startup) async {
    await tester.pumpWidget(MaterialApp(
      home: RouteSplash(
        startup: startup,
        homeBuilder: (_) => const Scaffold(body: Text('Főképernyő')),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('goes to the home screen once the cache has been filled',
      (tester) async {
    final startup = _FakeStartup(bootstrapped: true, importSucceeds: [true]);

    await pumpSplash(tester, startup);

    expect(find.text('Főképernyő'), findsOneWidget);
    expect(startup.imports, 0);
  });

  testWidgets('fills the cache on the first start, then goes on',
      (tester) async {
    final startup = _FakeStartup(bootstrapped: false, importSucceeds: [true]);

    await pumpSplash(tester, startup);

    expect(startup.imports, 1);
    expect(find.text('Főképernyő'), findsOneWidget);
  });

  testWidgets('a failed first import stops on an error with a retry, rather '
      'than going on to empty lists', (tester) async {
    final startup =
        _FakeStartup(bootstrapped: false, importSucceeds: [false, true]);

    await pumpSplash(tester, startup);

    expect(find.text('Főképernyő'), findsNothing);
    expect(
        find.text('Az adatok előkészítése nem sikerült. Próbáld újra.'),
        findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Újrapróbálás'));
    await tester.pumpAndSettle();

    expect(startup.imports, 2);
    expect(find.text('Főképernyő'), findsOneWidget);
  });
}
