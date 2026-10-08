import 'package:flutter/material.dart';
import 'package:miserend/theme/miserend_colors.dart';
import 'package:miserend/theme/tokens.dart';

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
    extensions: [MiserendColors.forScheme(scheme)],
  );
  return base.copyWith(
    // The title bar is the page's own surface, tinted only when the content
    // scrolls under it (KO2, MÉ3); the title stands where the platform puts
    // it (PL2), so `centerTitle` is left alone. The title is M3's
    // `titleLarge` in the foreground colour: a style given here would come
    // from [base.textTheme], which has no sizes yet.
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 3,
    ),
    // M3's elevated card: the tone alone hardly sets a card apart from the
    // page, so a low shadow does (KO1, MÉ1). No card overrides this but the
    // church card under a server error (SZ4). Half the gap above and half
    // below puts cards on a list 8 apart (TK2); the list's own padding keeps
    // them off the screen edge.
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      elevation: 1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Radii.m)),
      ),
      margin: const EdgeInsets.symmetric(vertical: Spacing.xs),
    ),
    // Text fields are outlined and the outline has to show: Material's
    // default border was once drawn white on white, and the problem
    // report's fields had to be guessed (KO12).
    inputDecorationTheme: InputDecorationTheme(
      border: _fieldBorder(scheme.outline),
      enabledBorder: _fieldBorder(scheme.outline),
      focusedBorder: _fieldBorder(scheme.primary, width: 2),
      errorBorder: _fieldBorder(scheme.error),
      focusedErrorBorder: _fieldBorder(scheme.error, width: 2),
    ),
    // Every SnackBar — the splash, the problem report, a church gone from
    // miserend.hu, an external app — floats on the inverse surface, for
    // Flutter's default 4 s (KO15); the text is M3's `onInverseSurface`
    // `bodyMedium`.
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.inverseSurface,
      actionTextColor: scheme.inversePrimary,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Radii.xs)),
      ),
    ),
  );
}

/// A text field's outline in [color] (KO12).
OutlineInputBorder _fieldBorder(Color color, {double width = 1}) =>
    OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(Radii.s)),
      borderSide: BorderSide(color: color, width: width),
    );
