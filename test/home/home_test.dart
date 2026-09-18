import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/database/cache/church_list_entry.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/home/churches/church_list_loader.dart';
import 'package:miserend/home/home.dart';
import 'package:miserend/home/search_suggestions.dart';
import 'package:provider/provider.dart';

import '../database/fake_favorites_service.dart';
import '../fake_location_provider.dart';
import 'advanced_search/fake_advanced_search_loader.dart';
import 'churches/fake_church_list_loader.dart';

/// Offers nothing, so that no test reads the device's cache.
class _NoSuggestions extends SearchSuggestions {
  @override
  Future<Suggestions> suggest(String term) async =>
      const Suggestions(churches: [], cities: []);
}

/// Offers Szeged as a city for any term.
class _SzegedSuggested extends SearchSuggestions {
  @override
  Future<Suggestions> suggest(String term) async =>
      const Suggestions(churches: [], cities: ['Szeged']);
}

void main() {
  Future<void> pumpHome(
    WidgetTester tester, {
    SearchSuggestions? suggestions,
    ChurchListLoader? searchResultsLoader,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<FavoritesService>.value(
        // Never loaded, so that the favorites' prefetch does not start.
        value: FakeFavoritesService(const [], loaded: false),
        child: MaterialApp(
          home: HomeScreen(
            tabBuilder: (index, isActive) => Text('Fül $index'),
            suggestions: suggestions ?? _NoSuggestions(),
            searchResultsLoader: searchResultsLoader,
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

  group('a search from the bar leaves it empty for the next one', () {
    Future<void> reopenSearchBar(WidgetTester tester) async {
      await tester.tap(find.byType(SearchBar));
      await tester.pumpAndSettle();
    }

    void expectEmptyBar(WidgetTester tester) {
      final field = tester.widget<TextField>(find.byType(TextField).last);
      expect(field.controller!.text, isEmpty);
      expect(find.widgetWithText(ListTile, 'Szeged'), findsNothing);
    }

    Future<void> pumpWithSzeged(WidgetTester tester) => pumpHome(
      tester,
      suggestions: _SzegedSuggested(),
      searchResultsLoader: FakeChurchListLoader([const <ChurchListEntry>[]]),
    );

    testWidgets('after submitting', (tester) async {
      await pumpWithSzeged(tester);
      await typeIntoSearchBar(tester, 'Szeged');
      expect(find.widgetWithText(ListTile, 'Szeged'), findsOneWidget);

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await reopenSearchBar(tester);

      expectEmptyBar(tester);
    });

    testWidgets('after choosing a city', (tester) async {
      await pumpWithSzeged(tester);
      await typeIntoSearchBar(tester, 'Szeg');

      await tester.tap(find.widgetWithText(ListTile, 'Szeged'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await reopenSearchBar(tester);

      expectEmptyBar(tester);
    });

    testWidgets('after the Részletes kereső, which still takes the name', (
      tester,
    ) async {
      await pumpHome(tester, suggestions: _SzegedSuggested());
      await openAdvancedSearch(tester, 'Mátyás');
      expect(fieldText(tester, 'Templom neve'), 'Mátyás');

      await reopenSearchBar(tester);

      expectEmptyBar(tester);
    });
  });
}
