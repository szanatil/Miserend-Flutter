import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/church_details/widgets/mass_info.dart';
import 'package:miserend/database/cache/cached_mass.dart';
import 'package:miserend/theme/miserend_theme.dart';

import '../../theme/theme_harness.dart';

final CachedMass _mass = CachedMass(
  id: 1,
  apiMassId: 1,
  churchId: 38,
  time: DateTime(2026, 10, 7, 18, 30),
  info: 'Gitáros mise a kápolnában',
  source: MassSource.nearbyMasses,
);

void main() {
  Future<void> openSheet(
    WidgetTester tester, {
    double width = 400,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MaterialApp(
        theme: miserendTheme(Brightness.light),
        home: Scaffold(
          body: Builder(
            builder:
                (context) => TextButton(
                  onPressed: () => MassInfo.show(context, _mass),
                  child: const Text('Megnyitás'),
                ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Megnyitás'));
    await tester.pumpAndSettle();
  }

  testWidgets('the time is titleLarge w600 with tabular figures (TI2, TI4)', (
    tester,
  ) async {
    await openSheet(tester);

    final time = find.text('18:30');
    final style = drawnStyle(tester, time);
    expect(
      style.fontSize,
      Theme.of(tester.element(time)).textTheme.titleLarge!.fontSize,
    );
    expect(style.fontWeight, FontWeight.w600);
    expect(style.fontFeatures, [const FontFeature.tabularFigures()]);
    expect(find.text('Gitáros mise a kápolnában'), findsOneWidget);
  });

  group('fits (EH4)', () {
    for (final width in eh4Widths) {
      for (final textScale in eh4TextScales) {
        testWidgets('at $width dp and text scale $textScale', (tester) async {
          await openSheet(tester, width: width, textScale: textScale);

          expect(find.text('18:30'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
