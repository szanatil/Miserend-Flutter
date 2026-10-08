import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/theme/adaptive.dart';
import 'package:miserend/theme/miserend_theme.dart';

final TargetPlatformVariant _bothPlatforms = TargetPlatformVariant(const {
  TargetPlatform.android,
  TargetPlatform.iOS,
});

const List<MiserendDestination> _destinations = [
  MiserendDestination(icon: Icon(Icons.church_rounded), label: 'Templomok'),
  MiserendDestination(
    icon: ImageIcon(AssetImage('assets/images/chalice.png')),
    label: 'Misék',
  ),
  MiserendDestination(icon: Icon(Icons.map_rounded), label: 'Térkép'),
  MiserendDestination(
    icon: Icon(Icons.info_outline_rounded),
    selectedIcon: Icon(Icons.info_rounded),
    label: 'Névjegy',
  ),
];

void main() {
  Future<void> pumpBar(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    int selectedIndex = 0,
    ValueChanged<int>? onSelected,
    Size size = const Size(430, 900),
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: miserendTheme(brightness),
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
        home: Scaffold(
          bottomNavigationBar: MiserendNavigationBar(
            destinations: _destinations,
            selectedIndex: selectedIndex,
            onDestinationSelected: onSelected ?? (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool isIOS() => defaultTargetPlatform == TargetPlatform.iOS;

  ColorScheme scheme(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(MiserendNavigationBar))).colorScheme;

  /// The colour the bar gives [icon].
  Color? iconColor(WidgetTester tester, IconData icon) =>
      IconTheme.of(tester.element(find.byIcon(icon))).color;

  /// The colour the bar gives the Misék tab's chalice.
  Color? chaliceColor(WidgetTester tester) =>
      IconTheme.of(tester.element(find.byType(ImageIcon))).color;

  testWidgets('is the platform\'s own bar (KO16, PL2)', (tester) async {
    await pumpBar(tester);

    expect(find.byType(NavigationBar), isIOS() ? findsNothing : findsOneWidget);
    expect(
      find.byType(CupertinoTabBar),
      isIOS() ? findsOneWidget : findsNothing,
    );
  }, variant: _bothPlatforms);

  testWidgets('shows every label, the unselected ones too (NA6)', (
    tester,
  ) async {
    await pumpBar(tester);

    for (final label in ['Templomok', 'Misék', 'Térkép', 'Névjegy']) {
      expect(find.text(label).hitTestable(), findsOneWidget);
    }
    if (!isIOS()) {
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).labelBehavior,
        NavigationDestinationLabelBehavior.alwaysShow,
      );
    }
  }, variant: _bothPlatforms);

  testWidgets('tells which tab was tapped', (tester) async {
    int? tapped;
    await pumpBar(tester, onSelected: (index) => tapped = index);

    await tester.tap(find.text('Térkép'));

    expect(tapped, 2);
  }, variant: _bothPlatforms);

  testWidgets('shows the filled icon on the selected tab only (IK2)', (
    tester,
  ) async {
    await pumpBar(tester, selectedIndex: 3);
    expect(find.byIcon(Icons.info_rounded), findsOneWidget);
    expect(find.byIcon(Icons.info_outline_rounded), findsNothing);

    await pumpBar(tester, selectedIndex: 0);
    expect(find.byIcon(Icons.info_rounded), findsNothing);
    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
  }, variant: _bothPlatforms);

  for (final brightness in Brightness.values) {
    testWidgets('wears its roles in $brightness (KO16, IK4)', (tester) async {
      await pumpBar(tester, brightness: brightness);
      final colors = scheme(tester);

      if (isIOS()) {
        final bar = tester.widget<CupertinoTabBar>(
          find.byType(CupertinoTabBar),
        );
        expect(bar.activeColor, colors.primary);
        expect(bar.inactiveColor, colors.onSurfaceVariant);
        expect(iconColor(tester, Icons.church_rounded), colors.primary);
        expect(iconColor(tester, Icons.map_rounded), colors.onSurfaceVariant);
        expect(chaliceColor(tester), colors.onSurfaceVariant);
      } else {
        final bar = find.byType(NavigationBar);
        final material = tester.widget<Material>(
          find.descendant(of: bar, matching: find.byType(Material)).first,
        );
        expect(material.color, colors.surfaceContainer);
        final indicator = tester.widget<NavigationIndicator>(
          find
              .descendant(of: bar, matching: find.byType(NavigationIndicator))
              .first,
        );
        expect(indicator.color, colors.secondaryContainer);
        expect(
          iconColor(tester, Icons.church_rounded),
          colors.onSecondaryContainer,
        );
        expect(iconColor(tester, Icons.map_rounded), colors.onSurfaceVariant);
        expect(chaliceColor(tester), colors.onSurfaceVariant);
      }
    }, variant: _bothPlatforms);

    testWidgets('tints the selected chalice like the icons in $brightness '
        '(IK1, IK4)', (tester) async {
      await pumpBar(tester, brightness: brightness, selectedIndex: 1);
      final colors = scheme(tester);

      expect(
        chaliceColor(tester),
        isIOS() ? colors.primary : colors.onSecondaryContainer,
      );
    }, variant: _bothPlatforms);
  }

  group('fits with every label on screen (EH4)', () {
    for (final width in [320.0, 430.0]) {
      for (final textScale in [1.0, 2.0]) {
        testWidgets('at $width dp and text scale $textScale', (tester) async {
          await pumpBar(tester, size: Size(width, 900), textScale: textScale);

          for (final label in ['Templomok', 'Misék', 'Térkép', 'Névjegy']) {
            expect(find.text(label).hitTestable(), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
        }, variant: _bothPlatforms);
      }
    }
  });
}
