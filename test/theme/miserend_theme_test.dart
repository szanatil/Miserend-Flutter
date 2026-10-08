import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/theme/miserend_theme.dart';
import 'package:miserend/theme/tokens.dart';

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
          theme: miserendTheme(Brightness.light).copyWith(platform: platform),
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
}
