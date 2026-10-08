import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/theme/miserend_theme.dart';

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
}
