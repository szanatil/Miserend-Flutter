import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/theme/miserend_colors.dart';
import 'package:miserend/theme/miserend_theme.dart';

/// The WCAG 2.2 contrast ratio of two opaque colours.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

void main() {
  group('MiserendColors', () {
    // DESIGN.md SZ3, as (light, dark).
    const expected = {
      'occasionTime': (Color(0xFFFF8C00), Color(0xFFFF8C00)),
      'onOccasionTime': (Color(0xFF2E1500), Color(0xFF2E1500)),
      'occasionTimeContainer': (Color(0xFFFFDCC2), Color(0xFF6E3900)),
      'onOccasionTimeContainer': (Color(0xFF2E1500), Color(0xFFFFDCC2)),
      'serverErrorContainer': (Color(0xFFFFE0B2), Color(0xFF5A3300)),
      'onServerErrorContainer': (Color(0xFF2E1500), Color(0xFFFFDCC2)),
      'serverErrorIcon': (Color(0xFFB45309), Color(0xFFFFB870)),
      'userLocation': (Color(0xFF1A73E8), Color(0xFF1A73E8)),
      'onUserLocation': (Color(0xFFFFFFFF), Color(0xFFFFFFFF)),
    };

    Map<String, Color> roles(MiserendColors c) => {
      'occasionTime': c.occasionTime,
      'onOccasionTime': c.onOccasionTime,
      'occasionTimeContainer': c.occasionTimeContainer,
      'onOccasionTimeContainer': c.onOccasionTimeContainer,
      'serverErrorContainer': c.serverErrorContainer,
      'onServerErrorContainer': c.onServerErrorContainer,
      'serverErrorIcon': c.serverErrorIcon,
      'userLocation': c.userLocation,
      'onUserLocation': c.onUserLocation,
    };

    for (final brightness in Brightness.values) {
      group('in $brightness', () {
        final theme = miserendTheme(brightness);
        final colors = theme.extension<MiserendColors>();

        test('is part of the theme with the SZ3 values', () {
          expect(colors, isNotNull);
          final actual = roles(colors!);
          for (final MapEntry(key: role, value: (light, dark))
              in expected.entries) {
            expect(
              actual[role],
              brightness == Brightness.light ? light : dark,
              reason: role,
            );
          }
          expect(
            colors.mapOverlay,
            theme.colorScheme.surface.withValues(alpha: 0.7),
          );
        });

        test('keeps text readable on its containers (AM1)', () {
          final c = colors!;
          for (final (fg, bg, name) in [
            (c.onOccasionTime, c.occasionTime, 'onOccasionTime'),
            (
              c.onOccasionTimeContainer,
              c.occasionTimeContainer,
              'onOccasionTimeContainer',
            ),
            (
              c.onServerErrorContainer,
              c.serverErrorContainer,
              'onServerErrorContainer',
            ),
          ]) {
            expect(_contrast(fg, bg), greaterThanOrEqualTo(4.5), reason: name);
          }
          expect(
            _contrast(c.serverErrorIcon, c.serverErrorContainer),
            greaterThanOrEqualTo(3),
          );
        });
      });
    }

    test('lerps between the light and the dark values', () {
      final light =
          miserendTheme(Brightness.light).extension<MiserendColors>()!;
      final dark = miserendTheme(Brightness.dark).extension<MiserendColors>()!;

      expect(
        light.lerp(dark, 0).occasionTimeContainer,
        const Color(0xFFFFDCC2),
      );
      expect(
        light.lerp(dark, 1).occasionTimeContainer,
        const Color(0xFF6E3900),
      );
      expect(light.copyWith(userLocation: Colors.red).userLocation, Colors.red);
    });
  });
}
