import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/home/home.dart';
import 'package:miserend/home/search_suggestions.dart';
import 'package:provider/provider.dart';

import '../database/fake_favorites_service.dart';
import '../fake_location_provider.dart';
import 'advanced_search/fake_advanced_search_loader.dart';

/// Offers nothing, so that no test reads the device's cache.
class _NoSuggestions extends SearchSuggestions {
  @override
  Future<Suggestions> suggest(String term) async =>
      const Suggestions(churches: [], cities: []);
}

void main() {
  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<FavoritesService>.value(
        // Never loaded, so that the favorites' prefetch does not start.
        value: FakeFavoritesService(const [], loaded: false),
        child: MaterialApp(
          home: HomeScreen(
            tabBuilder: (index, isActive) => Text('Fül $index'),
            suggestions: _NoSuggestions(),
            advancedSearchLoader: FakeAdvancedSearchLoader(const []),
            location: FakeLocationProvider(),
          ),
        ),
      ),
    );
  }

  Future<void> typeIntoSearchBar(WidgetTester tester, String text) async {
    await tester.tap(find.byType(SearchBar));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, text);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  Future<void> openAdvancedSearch(WidgetTester tester, String typed) async {
    await typeIntoSearchBar(tester, typed);
    // The open page's bar says the same.
    await tester.tap(find.widgetWithText(ListTile, 'Részletes kereső'));
    await tester.pumpAndSettle();
  }

  String fieldText(WidgetTester tester, String label) =>
      tester
          .widget<TextField>(find.widgetWithText(TextField, label))
          .controller!
          .text;

  testWidgets('the suggestions end with the Részletes kereső, even for a '
      'term too short to suggest anything', (tester) async {
    await pumpHome(tester);

    await typeIntoSearchBar(tester, 'Pé');

    expect(find.widgetWithText(ListTile, 'Részletes kereső'), findsOneWidget);
  });

  testWidgets('the Részletes kereső opens in the tab\'s place with the typed '
      'text as the name, the navigation still there', (tester) async {
    await pumpHome(tester);

    await openAdvancedSearch(tester, 'Mátyás');

    expect(find.text('Feltételek'), findsOneWidget);
    expect(fieldText(tester, 'Templom neve'), 'Mátyás');
    expect(find.text('Fül 0'), findsNothing);
    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });

  testWidgets('any tab closes the Részletes kereső, the selected one too', (
    tester,
  ) async {
    await pumpHome(tester);
    await openAdvancedSearch(tester, 'Mátyás');

    await tester.tap(find.text('Templomok'));
    await tester.pumpAndSettle();

    expect(find.text('Feltételek'), findsNothing);
    expect(find.text('Fül 0'), findsOneWidget);
  });

  testWidgets('going back closes the Részletes kereső', (tester) async {
    await pumpHome(tester);
    await openAdvancedSearch(tester, 'Mátyás');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Feltételek'), findsNothing);
    expect(find.text('Fül 0'), findsOneWidget);
  });

  testWidgets('a new Részletes kereső from the search bar starts without the '
      'last one\'s conditions', (tester) async {
    await pumpHome(tester);
    await openAdvancedSearch(tester, 'Mátyás');
    await tester.enterText(find.widgetWithText(TextField, 'Település'), 'Pécs');
    await tester.pump();

    await openAdvancedSearch(tester, 'Szent');

    expect(fieldText(tester, 'Templom neve'), 'Szent');
    expect(fieldText(tester, 'Település'), isEmpty);
  });
}
