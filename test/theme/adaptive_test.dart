import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/theme/adaptive.dart';
import 'package:miserend/theme/miserend_theme.dart';
import 'package:miserend/theme/tokens.dart';

import 'theme_harness.dart';

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

  group('the helpers (PL2, PL3)', () {
    late List<MethodCall> platformCalls;

    /// Pumps a button that runs [helper] and keeps what it returned in
    /// [results], then taps it.
    Future<void> open(
      WidgetTester tester,
      Future<Object?> Function(BuildContext context) helper, {
      List<Object?>? results,
      Size size = const Size(430, 900),
      double textScale = 1.0,
      Brightness brightness = Brightness.light,
    }) async {
      platformCalls = [];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          platformCalls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(
          theme: miserendTheme(brightness),
          home: Scaffold(
            body: Builder(
              builder:
                  (context) => TextButton(
                    onPressed: () async {
                      final result = await helper(context);
                      results?.add(result);
                    },
                    child: const Text('Megnyitás'),
                  ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Megnyitás'));
      await tester.pumpAndSettle();
    }

    bool lightImpact() => platformCalls.any(
      (call) =>
          call.method == 'HapticFeedback.vibrate' &&
          call.arguments == 'HapticFeedbackType.lightImpact',
    );

    Future<Object?> dialog(BuildContext context) => showMiserendDialog<bool>(
      context,
      title: 'Adatbázis nem található',
      content:
          'Az alkalmazás használatához szükség van az adatbázis '
              'letöltésére. Letölti most? ' *
          3,
      actions: const [
        MiserendDialogAction('Nem', false),
        MiserendDialogAction('Igen', true),
      ],
    );

    Future<Object?> sheet(BuildContext context) =>
        showMiserendActionSheet<String>(
          context,
          title: const Text('Nyelv'),
          actions: const [
            MiserendSheetAction(
              label: 'Bármelyik',
              value: '',
              leading: Icon(Icons.translate_rounded),
            ),
            MiserendSheetAction(label: 'magyar', value: 'hu'),
            MiserendSheetAction(label: 'szlovák', value: 'sk'),
          ],
        );

    testWidgets('a dialog is the platform\'s own, and closes with the tapped '
        'button\'s value (KO14)', (tester) async {
      final results = <Object?>[];
      await open(tester, dialog, results: results);

      expect(
        find.byType(CupertinoAlertDialog),
        isIOS() ? findsOneWidget : findsNothing,
      );
      // AlertDialog.adaptive is a subclass, which builds the Cupertino one
      // on iOS.
      expect(find.byWidgetPredicate((w) => w is AlertDialog), findsOneWidget);
      await tester.tap(find.text('Igen'));
      await tester.pumpAndSettle();

      expect(results, [true]);
    }, variant: _bothPlatforms);

    testWidgets('an action sheet is the platform\'s own, and closes with the '
        'chosen value (KO13)', (tester) async {
      final results = <Object?>[];
      await open(tester, sheet, results: results);

      if (isIOS()) {
        expect(find.byType(CupertinoActionSheet), findsOneWidget);
        expect(find.text('Mégse'), findsOneWidget);
      } else {
        final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
        expect(sheet.showDragHandle, isTrue);
        expect(
          sheet.shape,
          const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
          ),
        );
        expect(find.byType(CupertinoActionSheet), findsNothing);
      }
      await tester.tap(find.text('szlovák'));
      await tester.pumpAndSettle();

      expect(results, ['sk']);
      expect(lightImpact(), isIOS());
    }, variant: _bothPlatforms);

    testWidgets('an action sheet dismissed without a choice gives null', (
      tester,
    ) async {
      final results = <Object?>[];
      await open(tester, sheet, results: results);

      if (isIOS()) {
        await tester.tap(find.text('Mégse'));
      } else {
        await tester.tapAt(const Offset(10, 10));
      }
      await tester.pumpAndSettle();

      expect(results, [null]);
      expect(lightImpact(), isFalse);
    }, variant: _bothPlatforms);

    testWidgets('a date picker is the platform\'s own, and gives the day', (
      tester,
    ) async {
      final results = <Object?>[];
      await open(
        tester,
        (context) => pickMiserendDate(
          context,
          initialDate: DateTime(2026, 10, 9),
          firstDate: DateTime(2026, 10, 9),
          lastDate: DateTime(2026, 11, 9),
          helpText: 'Nap',
        ),
        results: results,
      );

      expect(
        find.byType(CupertinoDatePicker),
        isIOS() ? findsOneWidget : findsNothing,
      );
      expect(
        find.byType(DatePickerDialog),
        isIOS() ? findsNothing : findsOneWidget,
      );
      await tester.tap(find.text('Kész'));
      await tester.pumpAndSettle();

      expect(results, [DateTime(2026, 10, 9)]);
      expect(lightImpact(), isIOS());
    }, variant: _bothPlatforms);

    testWidgets('a time picker is the platform\'s own, on the 24-hour clock', (
      tester,
    ) async {
      final results = <Object?>[];
      await open(
        tester,
        (context) => pickMiserendTime(
          context,
          initialTime: const TimeOfDay(hour: 18, minute: 30),
        ),
        results: results,
      );

      if (isIOS()) {
        final picker = tester.widget<CupertinoDatePicker>(
          find.byType(CupertinoDatePicker),
        );
        expect(picker.mode, CupertinoDatePickerMode.time);
        expect(picker.use24hFormat, isTrue);
      } else {
        expect(find.byType(TimePickerDialog), findsOneWidget);
        expect(find.text('PM'), findsNothing);
      }
      await tester.tap(find.text('Kész'));
      await tester.pumpAndSettle();

      expect(results, [const TimeOfDay(hour: 18, minute: 30)]);
    }, variant: _bothPlatforms);

    testWidgets('a cancelled picker gives null', (tester) async {
      final results = <Object?>[];
      await open(
        tester,
        (context) => pickMiserendTime(
          context,
          initialTime: const TimeOfDay(hour: 18, minute: 30),
        ),
        results: results,
      );

      await tester.tap(find.text('Mégse'));
      await tester.pumpAndSettle();

      expect(results, [null]);
    }, variant: _bothPlatforms);

    testWidgets('a selection taps lightly on iOS only (PL2)', (tester) async {
      await open(tester, (context) async => miserendSelectionHaptic(context));

      expect(lightImpact(), isIOS());
    }, variant: _bothPlatforms);

    testWidgets('the system icons are the platform\'s own (IK1)', (
      tester,
    ) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          theme: miserendTheme(Brightness.light),
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(
        SystemIcon.close.of(context),
        isIOS() ? CupertinoIcons.xmark : Icons.close_rounded,
      );
      expect(
        SystemIcon.back.of(context),
        isIOS() ? CupertinoIcons.back : Icons.arrow_back_rounded,
      );
      expect(
        SystemIcon.share.of(context),
        isIOS() ? CupertinoIcons.share : Icons.share_rounded,
      );
      expect(
        SystemIcon.more.of(context),
        isIOS() ? CupertinoIcons.ellipsis : Icons.more_vert_rounded,
      );
    }, variant: _bothPlatforms);

    Future<Object?> datePicker(BuildContext context) => pickMiserendDate(
      context,
      initialDate: DateTime(2026, 10, 9),
      firstDate: DateTime(2026, 10, 9),
      lastDate: DateTime(2026, 11, 9),
      helpText: 'Nap',
    );

    for (final brightness in Brightness.values) {
      testWidgets('the iOS picker sheet stands on the bottom sheet\'s surface '
          'in $brightness (SZ5)', (tester) async {
        await open(tester, datePicker, brightness: brightness);

        final sheet = tester.widget<Material>(
          find
              .ancestor(
                of: find.byType(CupertinoDatePicker),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(sheet.color, schemeOf(brightness).surfaceContainerLow);
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
    }

    group('fit without overflow (EH4)', () {
      for (final width in [320.0, 430.0]) {
        for (final textScale in [1.0, 2.0]) {
          testWidgets('the date picker fits at $width dp and text scale '
              '$textScale', (tester) async {
            await open(
              tester,
              datePicker,
              size: Size(width, 640),
              textScale: textScale,
            );

            expect(find.text('Kész'), findsOneWidget);
            expect(tester.takeException(), isNull);
          }, variant: _bothPlatforms);

          testWidgets('the dialog fits at $width dp and text scale '
              '$textScale', (tester) async {
            await open(
              tester,
              dialog,
              size: Size(width, 640),
              textScale: textScale,
            );

            expect(find.text('Igen'), findsOneWidget);
            expect(tester.takeException(), isNull);
          }, variant: _bothPlatforms);

          testWidgets('the action sheet fits at $width dp and text scale '
              '$textScale', (tester) async {
            await open(
              tester,
              sheet,
              size: Size(width, 640),
              textScale: textScale,
            );

            expect(find.text('szlovák'), findsOneWidget);
            expect(tester.takeException(), isNull);
          }, variant: _bothPlatforms);
        }
      }
    });
  });
}
