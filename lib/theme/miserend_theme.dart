import 'package:flutter/material.dart';
import 'package:miserend/theme/miserend_colors.dart';

/// The app purple, the seed of both colour schemes (DESIGN.md SZ1).
const Color _seed = Color(0xFF5C27AE);

/// The app's look in [brightness], in one place so that every screen and
/// every message wears it. The light and the dark scheme both grow from the
/// purple (SZ1); the phone's wallpaper palette is not used (SZ2).
ThemeData miserendTheme(Brightness brightness) {
  var scheme = ColorScheme.fromSeed(
    seedColor: _seed,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    brightness: brightness,
  );
  // In light mode the purple is the brand's own, to the digit, however the
  // generation shifts it.
  if (brightness == Brightness.light) {
    scheme = scheme.copyWith(primary: _seed);
  }
  final base = ThemeData(
    colorScheme: scheme,
    extensions: [MiserendColors.of(scheme)],
  );
  return base.copyWith(
    appBarTheme: AppBarTheme(
      titleTextStyle: base.textTheme.titleLarge!.apply(color: scheme.onPrimary),
      iconTheme: IconThemeData(color: scheme.onPrimary),
      backgroundColor: scheme.primary,
    ),
    // Text fields are outlined and the outline has to show: Material's
    // default border was once drawn white on white, and the problem
    // report's fields had to be guessed.
    inputDecorationTheme: InputDecorationTheme(
      border: const OutlineInputBorder(),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    // The remaining SnackBars — the splash, the problem report, a church gone
    // from miserend.hu, an external app — used to wear Material's black,
    // which belongs to no other screen of the app (issue #23).
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.primary,
      contentTextStyle: TextStyle(color: scheme.onPrimary),
      actionTextColor: scheme.onPrimary,
    ),
  );
}
