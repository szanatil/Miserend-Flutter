import 'package:flutter/material.dart';

/// The spacing scale (DESIGN.md TK1); where each step goes is TK2. No other
/// value is used, apart from a commented `2` that aligns an icon with text.
abstract final class Spacing {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// The corner radius scale (DESIGN.md FO1); where each step goes is FO2.
abstract final class Radii {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 28;

  /// Fully rounded ends, for badges, buttons and the search bar.
  static const OutlinedBorder full = StadiumBorder();
}
