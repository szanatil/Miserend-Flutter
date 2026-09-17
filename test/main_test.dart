import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/colors.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/main.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // MyApp opens on the splash, which looks for the downloaded export.
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('the app theme', () {
    testWidgets('dresses the SnackBars in the app purple', (tester) async {
      await tester.pumpWidget(
        Builder(
          builder:
              (context) => MaterialApp(
                theme: miserendTheme(context),
                home: Scaffold(
                  body: Builder(
                    builder:
                        (context) => TextButton(
                          onPressed:
                              () => ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Nem sikerült elküldeni.'),
                                ),
                              ),
                          child: const Text('Mutasd'),
                        ),
                  ),
                ),
              ),
        ),
      );

      await tester.tap(find.text('Mutasd'));
      await tester.pumpAndSettle();

      final message = find.text('Nem sikerült elküldeni.');
      final bar =
          tester
              .widgetList<Material>(
                find.descendant(
                  of: find.byType(SnackBar),
                  matching: find.byType(Material),
                ),
              )
              .first;
      expect(bar.color, CustomColors.purple);
      expect(
        DefaultTextStyle.of(tester.element(message)).style.color,
        Colors.white,
        reason: 'readable on the purple',
      );
    });

    testWidgets('draws a text field\'s outline dark enough to see on white', (
      tester,
    ) async {
      // The purple swatch leaves the colour scheme's outline white, which is
      // what made the problem report's fields invisible.
      late ThemeData theme;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            theme = miserendTheme(context);
            return const SizedBox();
          },
        ),
      );

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

    testWidgets('is the one MyApp hands to MaterialApp', (tester) async {
      // The theme is worth nothing if MyApp stops passing it on. Only the
      // first frame is pumped: the splash behind it talks to the database.
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (context) => FavoritesService(),
          child: const MyApp(),
        ),
      );

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.theme?.snackBarTheme.backgroundColor, CustomColors.purple);
    });
  });
}
