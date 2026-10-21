import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/home/widgets/section_bar.dart';
import 'package:miserend/theme/miserend_theme.dart';

void main() {
  Future<void> pumpBar(
    WidgetTester tester,
    SectionBar bar, {
    Brightness brightness = Brightness.light,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: miserendTheme(brightness),
        home: DefaultTabController(
          length: 2,
          child: Scaffold(appBar: bar, body: const SizedBox.shrink()),
        ),
      ),
    );
  }

  Material materialOf(WidgetTester tester) => tester.widget<Material>(
    find
        .descendant(
          of: find.byType(SectionBar),
          matching: find.byType(Material),
        )
        .first,
  );

  const tabs = SectionBar.tabs([Tab(text: 'Közeli'), Tab(text: 'Kedvencek')]);

  for (final brightness in Brightness.values) {
    group('in $brightness', () {
      final theme = miserendTheme(brightness);

      testWidgets('a title bar says its title as a section title (TI2)', (
        tester,
      ) async {
        await pumpBar(
          tester,
          const SectionBar.title('Mai misék'),
          brightness: brightness,
        );

        final style = tester.widget<Text>(find.text('Mai misék')).style!;
        // M3 titleMedium.
        expect(style.fontSize, 16);
        expect(style.fontWeight, FontWeight.w600);
        expect(style.color, theme.colorScheme.onSurface);
      });

      for (final bar in [tabs, const SectionBar.title('Mai misék')]) {
        testWidgets('${bar.tabs != null ? 'a tab' : 'a title'} bar is flat on '
            'the surface, like the title bar (KO2, MÉ2)', (tester) async {
          await pumpBar(tester, bar, brightness: brightness);

          expect(materialOf(tester).color, theme.colorScheme.surface);
          expect(materialOf(tester).elevation, 0);
        });
      }

      testWidgets('the tabs wear the M3 defaults', (tester) async {
        await pumpBar(tester, tabs, brightness: brightness);

        final tabBar = tester.widget<TabBar>(find.byType(TabBar));
        expect(tabBar.labelColor, isNull);
        expect(tabBar.unselectedLabelColor, isNull);
        expect(tabBar.indicatorColor, isNull);
      });
    });
  }

  testWidgets('a title bar is as tall as a tab bar', (tester) async {
    await pumpBar(tester, tabs);
    final tabsHeight = tester.getSize(find.byType(SectionBar)).height;
    expect(find.text('Közeli'), findsOneWidget);

    await pumpBar(tester, const SectionBar.title('Mai misék'));

    expect(tester.getSize(find.byType(SectionBar)).height, tabsHeight);
  });

  for (final width in [320.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('fits at $width dp and text scale $scale (EH4)', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        for (final bar in [
          tabs,
          const SectionBar.title('Mai misék'),
          const SectionBar.title('Térkép'),
          SectionBar.title('Részletes kereső', onBack: () {}),
        ]) {
          await pumpBar(tester, bar);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
