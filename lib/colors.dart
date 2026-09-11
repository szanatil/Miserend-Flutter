import 'package:flutter/material.dart';

class CustomColors {
  static const MaterialColor purple = MaterialColor(
    0xFF5C27AE,
    <int, Color>{
      50: Color(0xFF5C27AE),
      100: Color(0xFF5C27AE),
      200: Color(0xFF5C27AE),
      300: Color(0xFF5C27AE),
      400: Color(0xFF5C27AE),
      500: Color(0xFF5C27AE),
      600: Color(0xFF5C27AE),
      700: Color(0xFF5C27AE),
      800: Color(0xFF5C27AE),
      900: Color(0xFF5C27AE),
    },
  );

  /// The accent behind mass times and the call-to-action links. It used to be
  /// written out at each use site, which meant two copies drifting apart.
  static const Color accent = Color.fromARGB(255, 255, 140, 0);
}