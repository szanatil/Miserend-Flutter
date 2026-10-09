import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:miserend/theme/adaptive.dart';
import 'package:miserend/theme/miserend_colors.dart';
import 'package:miserend/theme/tokens.dart';

/// The app purple, the seed of both colour schemes (DESIGN.md SZ1).
const Color _seed = Color(0xFF5C27AE);

/// The app's look in [brightness], in one place so that every screen and
/// every message wears it. The light and the dark scheme both grow from the
/// purple (SZ1); the phone's wallpaper palette is not used (SZ2).
///
/// The [platform] is the phone's unless a test gives one; it picks the touch
/// feedback, so it is set here rather than with `copyWith` later (PL2).
ThemeData miserendTheme(Brightness brightness, {TargetPlatform? platform}) {
  final target = platform ?? defaultTargetPlatform;
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
    platform: target,
    // Android's ripple; on iOS a tap only highlights, as there (PL2).
    splashFactory: switch (target) {
      TargetPlatform.iOS || TargetPlatform.macOS => NoSplash.splashFactory,
      _ => InkSparkle.splashFactory,
    },
    // Android's predictive back; on iOS the page slides and can be dragged
    // back from the edge (PL2).
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    // An iOS switch is on in the selection colour, `primary`, not in its
    // own green (SZ4).
    cupertinoOverrideTheme: const CupertinoThemeData(applyThemeToAll: true),
    // Every back and close button, the title bar's own included, wears the
    // platform's system icon (PL2).
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (context) => Icon(SystemIcon.back.of(context)),
      closeButtonIconBuilder: (context) => Icon(SystemIcon.close.of(context)),
    ),
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
    // A text button's icon is a regular one, 24, not M3's 18: 18 is for
    // chips and strips only (IK3).
    textButtonTheme: const TextButtonThemeData(
      style: ButtonStyle(iconSize: WidgetStatePropertyAll(24)),
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

/// The text roles DESIGN.md TI2 builds from a [TextTheme] role with a weight.
extension MiserendTextRoles on TextTheme {
  /// A section's title on a page: a card's heading, or one inside a card
  /// such as "Ma" (TI2).
  TextStyle? get sectionTitle =>
      titleMedium?.copyWith(fontWeight: FontWeight.w600);
}
