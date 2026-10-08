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

/// The soft shadows of the map's own marks, the one place outside the M3
/// elevations that has a shadow of its own (DESIGN.md MÉ2, KO17): they lift
/// the mark off any tile without a card under it.
abstract final class MapShadows {
  /// Under a group of churches (spec 0012).
  static const List<BoxShadow> group = [
    BoxShadow(color: Color(0x42000000), blurRadius: 3),
  ];

  /// Under the user's own dot (spec 0006).
  static const List<BoxShadow> userLocation = [
    BoxShadow(color: Color(0x42000000), blurRadius: 4, spreadRadius: 1),
  ];
}
