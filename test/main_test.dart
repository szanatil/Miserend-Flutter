import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/main.dart';
import 'package:miserend/theme/miserend_theme.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // MyApp opens on the splash, which looks for the downloaded export.
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('the app theme', () {
    test('draws a text field\'s outline dark enough to see on white', () {
      // A white outline once made the problem report's fields invisible.
      final theme = miserendTheme(Brightness.light);

      final decoration = const InputDecoration().applyDefaults(
        theme.inputDecorationTheme,
      );
      for (final border in [
        decoration.enabledBorder,
        decoration.focusedBorder,
      ]) {
        expect(border, isA<OutlineInputBorder>());
        expect(
          (border! as OutlineInputBorder).borderSide.color.computeLuminance(),
          lessThan(0.5),
        );
      }
    });

    testWidgets('is the one MyApp hands to MaterialApp, light and dark', (
      tester,
    ) async {
      // The theme is worth nothing if MyApp stops passing it on. Only the
      // first frame is pumped: the splash behind it talks to the database.
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (context) => FavoritesService(),
          child: const MyApp(),
        ),
      );

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.theme?.colorScheme.primary, const Color(0xFF5C27AE));
      expect(app.darkTheme?.colorScheme.brightness, Brightness.dark);
      // Dark mode follows the phone (SZ6).
      expect(app.themeMode, ThemeMode.system);
      expect(app.title, 'Miserend');
    });
  });
}
