import 'package:flutter/material.dart';

class CustomColors {
  static const MaterialColor purple = MaterialColor(0xFF5C27AE, <int, Color>{
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
  });

  /// The accent behind mass times and the call-to-action links. It used to be
  /// written out at each use site, which meant two copies drifting apart.
  static const Color accent = Color.fromARGB(255, 255, 140, 0);

  /// Behind what a server error leaves on screen (CONTEXT.md, „Szerverhiba"):
  /// the lists' banner, the map's church card and the details page. A user
  /// with signal does not expect stale data, so it has to stand out more than
  /// no connection does.
  static const Color serverErrorTint = Color(0xFFFFE0B2);

  /// The server error's icons, readable on [serverErrorTint].
  static const Color serverErrorAccent = Color(0xFFB45309);

  /// Behind the strips that inform rather than warn: the lists' no-connection
  /// banner and the map's **Helyzet nem elérhető** strip. Quieter than
  /// [serverErrorTint], which marks something the user did not expect.
  static const Color noticeTint = Color(0xFFEEEEEE);
}
