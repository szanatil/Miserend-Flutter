import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/theme/miserend_theme.dart';
import 'package:miserend/theme/tokens.dart';

import 'theme_harness.dart';

void main() {
  const seed = Color(0xFF5C27AE);

  group('the colour scheme', () {
    test('is the app purple in light mode (SZ1)', () {
      expect(miserendTheme(Brightness.light).colorScheme.primary, seed);
    });

    for (final brightness in Brightness.values) {
      test('comes from the purple seed in $brightness (SZ1)', () {
        final scheme = miserendTheme(brightness).colorScheme;
        final generated = ColorScheme.fromSeed(
          seedColor: seed,
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
          brightness: brightness,
        );

        expect(scheme.brightness, brightness);
        expect(scheme.secondary, generated.secondary);
        expect(scheme.surface, generated.surface);
        expect(scheme.outline, generated.outline);
        if (brightness == Brightness.dark) {
          expect(scheme.primary, generated.primary);
        }
      });
    }
  });

  for (final brightness in Brightness.values) {
    group('in $brightness', () {
      final theme = miserendTheme(brightness);
      final scheme = theme.colorScheme;

      testWidgets('the title bar is surface-coloured and flat (KO2, MÉ3)', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              appBar: AppBar(title: const Text('Cím')),
              body: const SizedBox.shrink(),
            ),
          ),
        );

        final bar = tester.widget<Material>(
          find
              .descendant(
                of: find.byType(AppBar),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(bar.color, scheme.surface);
        expect(bar.elevation, 0);
        expect(theme.appBarTheme.scrolledUnderElevation, 3);
        expect(theme.appBarTheme.centerTitle, isNull);
        final title = tester.widget<DefaultTextStyle>(
          find
              .ancestor(
                of: find.text('Cím'),
                matching: find.byType(DefaultTextStyle),
              )
              .first,
        );
        expect(title.style.color, scheme.onSurface);
        // M3 titleLarge.
        expect(title.style.fontSize, 22);
      });

      testWidgets('a card is surfaceContainerLow, raised 1, with 12 '
          'corners, outlined in dark mode only, 8 apart (KO1, MÉ1, FO2)', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Scaffold(
              body: Column(
                children: [
                  Card(child: SizedBox(height: 40)),
                  Card(child: SizedBox(height: 40)),
                ],
              ),
            ),
          ),
        );

        final surface = tester.widget<Material>(
          find
              .descendant(
                of: find.byType(Card).first,
                matching: find.byType(Material),
              )
              .first,
        );
        expect(surface.color, scheme.surfaceContainerLow);
        expect(surface.elevation, 1);
        expect(
          surface.shape,
          RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(Radii.m)),
            // In dark mode the shadow does not show, so the outline is the
            // card's edge (MÉ1).
            side:
                brightness == Brightness.dark
                    ? BorderSide(color: scheme.outlineVariant)
                    : BorderSide.none,
          ),
        );
        Rect surfaceOf(Finder card) => tester.getRect(
          find.descendant(of: card, matching: find.byType(Material)).first,
        );
        final first = surfaceOf(find.byType(Card).first);
        final second = surfaceOf(find.byType(Card).last);
        expect(second.top - first.bottom, Spacing.s);
      });

      testWidgets('a SnackBar floats on inverseSurface for 4 s (KO15)', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Builder(
                builder:
                    (context) => TextButton(
                      onPressed:
                          () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Üzenet')),
                          ),
                      child: const Text('Mutasd'),
                    ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Mutasd'));
        await tester.pumpAndSettle();

        final material = tester.widget<Material>(
          find
              .descendant(
                of: find.byType(SnackBar),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(material.color, scheme.inverseSurface);
        expect(
          material.shape,
          const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(Radii.xs)),
          ),
        );
        expect(
          tester.widget<SnackBar>(find.byType(SnackBar)).behavior ??
              theme.snackBarTheme.behavior,
          SnackBarBehavior.floating,
        );
        expect(
          tester
              .widget<RichText>(
                find.descendant(
                  of: find.text('Üzenet'),
                  matching: find.byType(RichText),
                ),
              )
              .text
              .style
              ?.color,
          scheme.onInverseSurface,
        );
        expect(theme.snackBarTheme.actionTextColor, scheme.inversePrimary);

        await tester.pump(const Duration(milliseconds: 3900));
        expect(find.text('Üzenet'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
        expect(find.text('Üzenet'), findsNothing);
      });

      testWidgets(
        'a text field is outlined, primary 2 dp when focused (KO12)',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: const Scaffold(
                body: TextField(decoration: InputDecoration(labelText: 'Név')),
              ),
            ),
          );
          final decorations = theme.inputDecorationTheme;
          const radius = BorderRadius.all(Radius.circular(Radii.s));

          expect(
            decorations.enabledBorder,
            OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: scheme.outline),
            ),
          );
          expect(
            decorations.focusedBorder,
            OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: scheme.primary, width: 2),
            ),
          );
          expect(
            decorations.errorBorder,
            OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: scheme.error),
            ),
          );
          expect(
            decorations.focusedErrorBorder,
            OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: scheme.error, width: 2),
            ),
          );

          await tester.tap(find.byType(TextField));
          await tester.pump();
          expect(
            tester
                .widget<InputDecorator>(find.byType(InputDecorator))
                .isFocused,
            isTrue,
          );
        },
      );
    });
  }

  group('a tooltip (KO21)', () {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      for (final brightness in Brightness.values) {
        testWidgets('is solid inverseSurface with xs corners, its text '
            'onInverseSurface bodySmall, at least 24 tall, on $platform in '
            '$brightness', (tester) async {
          final theme = miserendTheme(brightness, platform: platform);
          final scheme = theme.colorScheme;
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(
                body: Center(
                  child: IconButton(
                    tooltip: 'Bezárás',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {},
                  ),
                ),
              ),
            ),
          );

          await tester.longPress(find.byType(IconButton));
          await tester.pump(const Duration(milliseconds: 200));

          final box = tooltipBox('Bezárás');
          final decoration =
              tester.widget<DecoratedBox>(box).decoration as BoxDecoration;
          expect(decoration.color, scheme.inverseSurface);
          expect(decoration.color!.a, 1);
          expect(
            decoration.borderRadius,
            const BorderRadius.all(Radius.circular(Radii.xs)),
          );
          expect(decoration.boxShadow, isNull);
          final style = drawnStyle(tester, tooltipText('Bezárás'));
          final bodySmall =
              Theme.of(
                tester.element(find.byType(IconButton)),
              ).textTheme.bodySmall!;
          expect(style.color, scheme.onInverseSurface);
          expect(style.fontSize, bodySmall.fontSize);
          final rect = tester.getRect(box);
          final text = tester.getRect(tooltipText('Bezárás'));
          expect(rect.height, greaterThanOrEqualTo(24));
          expect(text.left - rect.left, Spacing.s);
          expect(rect.right - text.right, Spacing.s);
          expect(
            theme.tooltipTheme.padding,
            const EdgeInsets.symmetric(
              horizontal: Spacing.s,
              vertical: Spacing.xs,
            ),
          );
        });
      }
    }

    testWidgets('of an icon button stays 1.5 s after the long press', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: miserendTheme(Brightness.light),
          home: Scaffold(
            body: Center(
              child: IconButton(
                tooltip: 'Bezárás',
                icon: const Icon(Icons.close_rounded),
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      await tester.longPress(find.byType(IconButton));
      await tester.pump(const Duration(milliseconds: 1400));
      expect(tooltipText('Bezárás'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(tooltipText('Bezárás'), findsNothing);
    });
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('the title stands where $platform puts it (PL2)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: miserendTheme(Brightness.light, platform: platform),
          home: Scaffold(
            appBar: AppBar(title: const Text('Cím')),
            body: const SizedBox.shrink(),
          ),
        ),
      );

      final centre = tester.getCenter(find.text('Cím')).dx;
      if (platform == TargetPlatform.iOS) {
        expect(centre, moreOrLessEquals(200, epsilon: 1));
      } else {
        expect(centre, lessThan(100));
      }
    });
  }

  group('on each platform (PL2)', () {
    test('Android has predictive back and the ripple', () {
      final theme = miserendTheme(
        Brightness.light,
        platform: TargetPlatform.android,
      );

      expect(theme.platform, TargetPlatform.android);
      expect(
        theme.pageTransitionsTheme.builders[TargetPlatform.android],
        isA<PredictiveBackPageTransitionsBuilder>(),
      );
      expect(theme.splashFactory, InkSparkle.splashFactory);
    });

    test('iOS slides the page and has no ripple', () {
      final theme = miserendTheme(
        Brightness.light,
        platform: TargetPlatform.iOS,
      );

      expect(theme.platform, TargetPlatform.iOS);
      expect(
        theme.pageTransitionsTheme.builders[TargetPlatform.iOS],
        isA<CupertinoPageTransitionsBuilder>(),
      );
      expect(theme.splashFactory, NoSplash.splashFactory);
    });

    test('the platform is the phone\'s unless given', () {
      expect(miserendTheme(Brightness.light).platform, defaultTargetPlatform);
    });

    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      testWidgets('the back button wears $platform\'s system icon', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: miserendTheme(Brightness.light, platform: platform),
            home: const Scaffold(body: Center(child: BackButton())),
          ),
        );

        expect(
          find.byIcon(
            platform == TargetPlatform.iOS
                ? CupertinoIcons.back
                : Icons.arrow_back_rounded,
          ),
          findsOneWidget,
        );
      });
    }
  });
}
