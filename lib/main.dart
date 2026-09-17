import 'package:flutter/material.dart';
import 'package:miserend/colors.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/splash.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => FavoritesService(),
      child: const MyApp(),
    ),
  );
}

/// The app's look, in one place so that every screen and every message wears
/// it. Takes the context for the text styles it recolours.
ThemeData miserendTheme(BuildContext context) {
  return ThemeData(
    colorScheme: ColorScheme.fromSwatch(primarySwatch: CustomColors.purple),
    appBarTheme: AppBarTheme(
      titleTextStyle: Theme.of(
        context,
      ).textTheme.titleLarge!.apply(color: Colors.white),
      iconTheme: IconThemeData(color: Colors.white),
      backgroundColor: CustomColors.purple,
    ),
    // Text fields are outlined and the outline has to show: the purple swatch
    // leaves the scheme's `outline` white, so Material's default border was
    // drawn white on white and the problem report's fields had to be guessed.
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.black38),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: CustomColors.purple, width: 2),
      ),
    ),
    // The remaining SnackBars — the splash, the problem report, a church gone
    // from miserend.hu, an external app — used to wear Material's black,
    // which belongs to no other screen of the app (issue #23).
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: CustomColors.purple,
      contentTextStyle: TextStyle(color: Colors.white),
      actionTextColor: Colors.white,
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: miserendTheme(context),
      home: const RouteSplash(),
    );
  }
}
