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
