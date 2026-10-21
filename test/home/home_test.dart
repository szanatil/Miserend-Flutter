import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/api/nearby_masses_item.dart';
import 'package:miserend/church_details/church_details_page.dart';
import 'package:miserend/church_details/church_page_data.dart';
import 'package:miserend/church_details/church_schedule_loader.dart';
import 'package:miserend/church_details/report_problem_page.dart';
import 'package:miserend/database/cache/cached_mass.dart';
import 'package:miserend/database/cache/church_details.dart';
import 'package:miserend/database/cache/church_list_entry.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/home/churches/church_card.dart';
import 'package:miserend/home/churches/church_list_loader.dart';
import 'package:miserend/home/churches/churches_page.dart';
import 'package:miserend/home/churches/search_results.dart';
import 'package:miserend/home/home.dart';
import 'package:miserend/home/masses/mass_card.dart';
import 'package:miserend/home/masses/near_masses_page.dart';
import 'package:miserend/home/masses/nearest_masses.dart';
import 'package:miserend/home/masses/nearest_masses_loader.dart';
import 'package:miserend/home/search_suggestions.dart';
import 'package:miserend/theme/adaptive.dart';
import 'package:miserend/theme/miserend_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../church_details/fake_church_schedule_loader.dart';
import '../database/fake_favorites_service.dart';
import '../fake_location_provider.dart';
import 'advanced_search/fake_advanced_search_loader.dart';
import 'churches/fake_church_list_loader.dart';
import 'fake_search_suggestions.dart';

/// Offers Szeged as a city for any term.
class _SzegedSuggested extends SearchSuggestions {
  @override
  Future<Suggestions> suggest(String term) async =>
      const Suggestions(churches: [], cities: ['Szeged']);
}

/// One mass at noon, so that the Misék tab has a card to open.
class _OneMass extends NearestMassesLoader {
  @override
  Future<List<NearbyMassesItem>> fetch(DateTime now) async => [
    NearbyMassesItem(
      churchId: 1,
      churchName: 'Szent István-bazilika',
      city: 'Budapest V. kerület',
      lat: 47.5007789,
      lon: 19.0539695,
      distanceKm: 1.08,
      start: DateTime(2026, 9, 14, 12, 30),
      title: 'Szentmise',
    ),
  ];

  @override
  Future<MassDetails> fetchMassDetails(
    List<NearbyMassesItem> masses,
    DateTime now,
  ) async => const MassDetails();

  @override
  Future<String?> thumbnailUrl(int churchId) async => null;
}

const ChurchListEntry _church = ChurchListEntry(
  id: 38,
  name: 'Belvárosi Nagyboldogasszony-templom',
  commonName: null,
  city: 'Budapest V. kerület',
  lat: 47.4925,
  lon: 19.0532,
  photo: null,
  masses: [],
);

/// A church with something in every section, so that the size tests see
/// the whole page rather than its empty frame.
final ChurchPageData _fullPage = ChurchPageData(
  church: ChurchDetails(
    id: 38,
    name: 'Belvárosi Nagyboldogasszony Főplébánia-templom',
    commonName: 'Belvárosi templom',
    names: const [],
    alternativeNames: const [],
    country: 'Magyarország',
    diocese: 'Esztergom-Budapesti főegyházmegye',
    county: 'Budapest',
    city: 'Budapest V. kerület',
    street: 'Március 15. tér',
    gettingThere: 'A Ferenciek terétől két perc gyalog.',
    parish: null,
    description: 'Budapest legrégebbi temploma. ' * 8,
    accessibility: null,
    email: 'belvaros@example.hu',
    links: const ['https://www.belvarosiplebania.hu'],
    languages: const ['hu', 'de', 'en'],
    massScheduleNote: 'Nyáron a hétköznapi esti mise elmarad.',
    adorations: const [],
    hasConfession: true,
    communities: const [],
    lat: 47.4925,
    lon: 19.0532,
    photos: const [],
    updatedAt: null,
    localSyncedAt: null,
    isGreek: false,
  ),
  massesByDay: List.generate(
    ChurchScheduleLoader.scheduleDays,
    (day) => [
      for (final hour in [7, 9, 11, 18])
        CachedMass(
          id: null,
          apiMassId: null,
          churchId: 38,
          time: DateTime(2026, 9, 14 + day, hour, 30),
          info: 'Római katolikus Szentmise, gitáros, ifjúsági',
          source: MassSource.nearbyMasses,
        ),
    ],
  ),
  freshDays: ChurchScheduleLoader.scheduleDays,
  confessionLive: false,
);

/// A tab with a long list and, above it, the way to a church's details as
/// the church cards take it.
class _ListTab extends StatelessWidget {
  const _ListTab(this.index);

  final int index;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextButton(
          onPressed:
              () => openChurchDetails(
                context,
                _church,
                loader: FakeChurchScheduleLoader(_fullPage),
              ),
          child: const Text('Templom megnyitása'),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: 60,
            itemBuilder:
                (context, row) =>
                    SizedBox(height: 56, child: Text('Fül $index, $row. sor')),
          ),
        ),
      ],
    );
  }
}

final TargetPlatformVariant _bothPlatforms = TargetPlatformVariant(const {
  TargetPlatform.android,
  TargetPlatform.iOS,
});

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
            suggestions: suggestions ?? NoSearchSuggestions(),
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
    expect(find.byType(MiserendNavigationBar), findsOneWidget);
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

  group('moving between the tabs and their pages', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    /// The home screen with tabs to navigate in: long lists to scroll, the
    /// way to a church's details, and the Misék with one mass.
    Future<void> pumpHomeWithTabs(
      WidgetTester tester, {
      Size size = const Size(430, 900),
      double textScale = 1.0,
      Widget? churchesTab,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChangeNotifierProvider<FavoritesService>.value(
          // Never loaded, so that the favorites' prefetch does not start.
          value: FakeFavoritesService(const [], loaded: false),
          child: MaterialApp(
            theme: miserendTheme(Brightness.light),
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(textScale)),
                  child: child!,
                ),
            home: HomeScreen(
              tabBuilder:
                  (index, isActive) =>
                      index == 1
                          ? NearMassesPage(
                            isActive: isActive,
                            loader: _OneMass(),
                            clock: () => DateTime(2026, 9, 14, 12, 0),
                            detailsLoader: FakeChurchScheduleLoader(),
                            location: FakeLocationProvider(),
                          )
                          : index == 0 && churchesTab != null
                          ? churchesTab
                          : _ListTab(index),
              suggestions: NoSearchSuggestions(),
              searchResultsLoader: FakeChurchListLoader([
                const <ChurchListEntry>[],
              ]),
              advancedSearchLoader: FakeAdvancedSearchLoader(const []),
              location: FakeLocationProvider(),
              aboutBuilder:
                  (context) => Scaffold(
                    appBar: AppBar(title: const Text('Névjegy oldal')),
                    body: TextButton(
                      onPressed:
                          () => openChurchDetails(
                            context,
                            _church,
                            loader: FakeChurchScheduleLoader(),
                          ),
                      child: const Text('Mai templom'),
                    ),
                  ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// Not merely built: on screen and reachable by a tap.
    Finder navigationBar() => find.byType(MiserendNavigationBar).hitTestable();

    int selectedTab(WidgetTester tester) =>
        tester
            .widget<MiserendNavigationBar>(find.byType(MiserendNavigationBar))
            .selectedIndex;

    Future<void> tapTab(WidgetTester tester, String label) async {
      await tester.tap(
        find.descendant(
          of: find.byType(MiserendNavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// Which of the Templomok tab's own tabs is on screen.
    int currentChurchesTab(WidgetTester tester) =>
        DefaultTabController.of(tester.element(find.byType(TabBarView))).index;

    Future<void> openChurch(WidgetTester tester) async {
      await tester.tap(find.text('Templom megnyitása'));
      await tester.pumpAndSettle();
    }

    Future<void> goBack(WidgetTester tester) async {
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }

    group('the navigation bar stays on screen (NA1)', () {
      testWidgets('under the church details from the Templomok tab', (
        tester,
      ) async {
        await pumpHomeWithTabs(tester);

        await openChurch(tester);

        expect(find.byType(ChurchDetailsPage), findsOneWidget);
        expect(navigationBar(), findsOneWidget);
      }, variant: _bothPlatforms);

      testWidgets('under the church details from the Misék tab', (
        tester,
      ) async {
        await pumpHomeWithTabs(tester);
        await tapTab(tester, 'Misék');

        await tester.tap(find.byType(MassCard));
        await tester.pumpAndSettle();

        expect(find.byType(ChurchDetailsPage), findsOneWidget);
        expect(navigationBar(), findsOneWidget);
      }, variant: _bothPlatforms);

      testWidgets('under the search results', (tester) async {
        await pumpHomeWithTabs(tester);
        await tester.tap(find.byType(SearchBar));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, 'Szeged');

        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();

        expect(find.byType(SearchResultsPage), findsOneWidget);
        expect(navigationBar(), findsOneWidget);
      }, variant: _bothPlatforms);

      testWidgets('under the Névjegy', (tester) async {
        await pumpHomeWithTabs(tester);

        await tapTab(tester, 'Névjegy');

        expect(find.text('Névjegy oldal'), findsOneWidget);
        expect(navigationBar(), findsOneWidget);
      }, variant: _bothPlatforms);
    });

    testWidgets('the Hibajelentés covers the navigation bar, and Mégse closes '
        'it (NA2)', (tester) async {
      await pumpHomeWithTabs(tester);
      await openChurch(tester);

      await tester.tap(find.text('Hibajelentés'));
      await tester.pumpAndSettle();

      expect(find.byType(ReportProblemPage), findsOneWidget);
      expect(navigationBar(), findsNothing);

      await tester.tap(find.text('Mégse'));
      await tester.pumpAndSettle();

      expect(find.byType(ReportProblemPage), findsNothing);
      expect(find.byType(ChurchDetailsPage), findsOneWidget);
      expect(navigationBar(), findsOneWidget);
    }, variant: _bothPlatforms);

    group('tapping the tab on screen again (NA4)', () {
      testWidgets('goes back to its root from a deeper page', (tester) async {
        await pumpHomeWithTabs(tester);
        await openChurch(tester);

        await tapTab(tester, 'Templomok');

        expect(find.byType(ChurchDetailsPage), findsNothing);
        expect(find.text('Fül 0, 0. sor'), findsOneWidget);
      }, variant: _bothPlatforms);

      testWidgets('on the Templomok tab\'s Kedvencek, goes back to Közeli '
          'first', (tester) async {
        await pumpHomeWithTabs(
          tester,
          churchesTab: ChurchesPage(
            nearLoader: FakeChurchListLoader([const <ChurchListEntry>[]]),
            favoritesLoader: FakeChurchListLoader([const <ChurchListEntry>[]]),
            location: FakeLocationProvider(),
          ),
        );
        // The Kedvencek keeps loading, as the favorites never do here, so
        // the tab's animation is waited out rather than settled.
        await tester.tap(find.text('Kedvencek'));
        await tester.pump();
        await tester.pump(Durations.long2);
        expect(currentChurchesTab(tester), 1);

        await tester.tap(
          find.descendant(
            of: find.byType(MiserendNavigationBar),
            matching: find.text('Templomok'),
          ),
        );
        await tester.pump();
        await tester.pump(Durations.long2);

        expect(currentChurchesTab(tester), 0);
      }, variant: _bothPlatforms);

      testWidgets('scrolls its list to the top on the root', (tester) async {
        await pumpHomeWithTabs(tester);
        await tester.drag(find.byType(ListView), const Offset(0, -1500));
        await tester.pumpAndSettle();
        expect(find.text('Fül 0, 0. sor'), findsNothing);

        await tapTab(tester, 'Templomok');

        expect(find.text('Fül 0, 0. sor'), findsOneWidget);
      }, variant: _bothPlatforms);
    });

    group('going back (NA3)', () {
      testWidgets('steps back in the tab\'s own stack', (tester) async {
        await pumpHomeWithTabs(tester);
        await openChurch(tester);

        await goBack(tester);

        expect(find.byType(ChurchDetailsPage), findsNothing);
        expect(find.text('Fül 0, 0. sor'), findsOneWidget);
      }, variant: _bothPlatforms);

      testWidgets('from another tab\'s root, goes to the Templomok', (
        tester,
      ) async {
        await pumpHomeWithTabs(tester);
        await tapTab(tester, 'Térkép');
        expect(find.text('Fül 2, 0. sor'), findsOneWidget);

        await goBack(tester);

        expect(find.text('Fül 0, 0. sor'), findsOneWidget);
        expect(selectedTab(tester), 0);
      }, variant: TargetPlatformVariant.only(TargetPlatform.android));

      testWidgets('from the Templomok tab\'s root, leaves the app', (
        tester,
      ) async {
        final calls = <String>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            calls.add(call.method);
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await pumpHomeWithTabs(tester);

        await goBack(tester);

        expect(calls, contains('SystemNavigator.pop'));
      }, variant: TargetPlatformVariant.only(TargetPlatform.android));
    });

    group('switching tabs and coming back keeps (NA5)', () {
      testWidgets('the tab\'s stack', (tester) async {
        await pumpHomeWithTabs(tester);
        await openChurch(tester);

        await tapTab(tester, 'Térkép');
        await tapTab(tester, 'Templomok');

        expect(find.byType(ChurchDetailsPage), findsOneWidget);
      }, variant: _bothPlatforms);

      testWidgets('the tab\'s scroll position', (tester) async {
        await pumpHomeWithTabs(tester);
        await tester.drag(find.byType(ListView), const Offset(0, -1500));
        await tester.pumpAndSettle();
        final scrolledTo = tester.getTopLeft(find.text('Fül 0, 30. sor')).dy;

        await tapTab(tester, 'Térkép');
        await tapTab(tester, 'Templomok');

        expect(tester.getTopLeft(find.text('Fül 0, 30. sor')).dy, scrolledTo);
      }, variant: _bothPlatforms);
    });

    testWidgets('the Névjegy is a tab of its own: selected, and keeping its '
        'stack while away', (tester) async {
      await pumpHomeWithTabs(tester);
      await tapTab(tester, 'Névjegy');
      expect(selectedTab(tester), 3);
      await tester.tap(find.text('Mai templom'));
      await tester.pumpAndSettle();

      await tapTab(tester, 'Templomok');
      expect(find.byType(ChurchDetailsPage), findsNothing);
      await tapTab(tester, 'Névjegy');

      expect(find.byType(ChurchDetailsPage), findsOneWidget);
      expect(selectedTab(tester), 3);
    }, variant: _bothPlatforms);

    group('the church details fit beside the navigation bar (EH4)', () {
      for (final width in [320.0, 430.0]) {
        for (final textScale in [1.0, 2.0]) {
          testWidgets('at $width dp and text scale $textScale', (tester) async {
            await pumpHomeWithTabs(
              tester,
              // Tall enough for every section, so none is left unbuilt.
              size: Size(width, 2400),
              textScale: textScale,
            );

            await openChurch(tester);

            expect(find.byType(ChurchDetailsPage), findsOneWidget);
            expect(navigationBar(), findsOneWidget);
            expect(tester.takeException(), isNull);
          }, variant: _bothPlatforms);
        }
      }
    });
  });
}
