import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/splash.dart';
import 'package:miserend/theme/miserend_theme.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => FavoritesService(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Miserend',
      theme: miserendTheme(Brightness.light),
      darkTheme: miserendTheme(Brightness.dark),
      // Dark mode follows the phone; the app has no switch of its own (SZ6).
      themeMode: ThemeMode.system,
      // The app speaks Hungarian whatever the phone's language, and so do
      // Flutter's own texts: the date and time pickers, the tooltips.
      locale: const Locale('hu'),
      supportedLocales: const [Locale('hu')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const RouteSplash(),
      debugShowCheckedModeBanner: false,
    );
  }
}
