import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:miserend/about/about_page.dart';
import 'package:miserend/database/cache/church_list_entry.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/favorites_prefetch.dart';
import 'package:miserend/home/advanced_search/advanced_search_loader.dart';
import 'package:miserend/home/advanced_search/advanced_search_page.dart';
import 'package:miserend/home/churches/church_card.dart';
import 'package:miserend/home/churches/church_list_loader.dart';
import 'package:miserend/home/churches/churches_page.dart';
import 'package:miserend/home/churches/search_results.dart';
import 'package:miserend/home/map/map_page.dart';
import 'package:miserend/home/masses/near_masses_page.dart';
import 'package:miserend/home/search_suggestions.dart';
import 'package:miserend/home/widgets/search_suggestion_list.dart';
import 'package:miserend/home/widgets/section_bar.dart';
import 'package:miserend/home/widgets/tab_reselect.dart';
import 'package:miserend/location_provider.dart';
import 'package:miserend/theme/adaptive.dart';
import 'package:miserend/widgets/photo_decode.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.tabBuilder,
    this.suggestions,
    this.advancedSearchLoader,
    this.location,
    this.searchResultsLoader,
    this.aboutBuilder,
  });

  /// Injected by tests; the screen builds the real tabs otherwise. Told the
  /// tab's index and whether it is the one on screen.
  final Widget Function(int index, bool isActive)? tabBuilder;

  /// Injected by tests; the screen builds its own otherwise.
  final SearchSuggestions? suggestions;

  /// Injected by tests; the Részletes kereső builds its own otherwise.
  final AdvancedSearchLoader? advancedSearchLoader;

  /// Injected by tests; the Részletes kereső builds its own otherwise.
  final LocationProvider? location;

  /// Injected by tests; the search results page builds its own otherwise.
  final ChurchListLoader? searchResultsLoader;

  /// Injected by tests; the screen builds the real Névjegy otherwise.
  final WidgetBuilder? aboutBuilder;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

abstract class Suggestion {
  Suggestion({required this.onChosen});

  /// Told before the suggestion opens what it offers: a search from the bar
  /// closes the Részletes kereső and empties the bar (spec 0010, „Belépés").
  final VoidCallback onChosen;

  Widget buildWidget(BuildContext context);
}

class ChurchSuggestion extends Suggestion {
  static const double _thumbnailSize = 40;

  final ChurchListEntry church;

  ChurchSuggestion(this.church, {required super.onChosen});

  Widget _errorBuilder(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    return Image.asset(
      'assets/images/church_blurred.png',
      fit: BoxFit.cover,
      cacheHeight: PhotoDecode.forSlot(context, _thumbnailSize),
    );
  }

  @override
  Widget buildWidget(BuildContext context) {
    return ListTile(
      onTap: () {
        onChosen();
        openChurchDetails(context, church);
      },
      titleAlignment: ListTileTitleAlignment.center,
      leading: AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: FadeInImage.assetNetwork(
            fit: BoxFit.cover,
            placeholder: 'assets/images/church_blurred.png',
            image: church.photo ?? '',
            imageErrorBuilder: _errorBuilder,
            imageCacheHeight: PhotoDecode.forSlot(context, _thumbnailSize),
            placeholderCacheHeight: PhotoDecode.forSlot(
              context,
              _thumbnailSize,
            ),
          ),
        ),
      ),
      title: Text(church.name ?? ''),
    );
  }
}

class CitySuggestion extends Suggestion {
  String cityName = '';

  /// Injected by tests; the results page builds its own otherwise.
  final ChurchListLoader? resultsLoader;

  CitySuggestion(this.cityName, {required super.onChosen, this.resultsLoader});

  @override
  Widget buildWidget(BuildContext context) {
    return ListTile(
      onTap: () {
        onChosen();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => SearchResultsPage(
                  searchParams: SearchParams.fromCity(cityName),
                  loader: resultsLoader,
                ),
          ),
        );
      },
      titleAlignment: ListTileTitleAlignment.center,
      leading: AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Icon(Icons.location_city, color: Colors.black54, size: 24.0),
        ),
      ),
      title: Text(cityName),
    );
  }
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  late final SearchSuggestions _suggestions =
      widget.suggestions ?? SearchSuggestions();

  /// What the search bar held when the Részletes kereső was opened; null
  /// while it is closed.
  String? _advancedSearchName;

  /// Bumped each time the Részletes kereső opens, so that it starts over with
  /// empty conditions even when it was open already.
  int _advancedSearchRun = 0;

  bool get _advancedSearchOpen => _advancedSearchName != null;

  /// Tabs that have been opened at least once. Switching tabs used to drop the
  /// page out of the tree entirely, so coming back re-ran the all-churches
  /// query and asked for the location again. They are kept alive once built,
  /// and pages never opened are not built at all, so startup is unchanged.
  final Set<int> _builtTabs = <int>{0};

  /// Each tab's own stack (DESIGN.md NA1): what opens from a tab opens in
  /// it, above the navigation bar rather than over it.
  final List<GlobalKey<NavigatorState>> _tabNavigators = List.generate(
    _tabCount,
    (_) => GlobalKey<NavigatorState>(),
  );

  /// The stack of the tab on screen.
  NavigatorState? get _activeNavigator =>
      _tabNavigators[_selectedIndex].currentState;

  /// Each tab's root page, inside its route, where the route's primary
  /// scroll controller is in reach.
  final List<GlobalKey> _tabRoots = List.generate(
    _tabCount,
    (_) => GlobalKey(),
  );

  static const int _tabCount = 4;
  static const int _massesTab = 1;

  /// The Névjegy: a tab like the others, with a stack of its own, but no
  /// search bar over it.
  static const int _aboutTab = 3;

  /// What each tab's pages do when the tab is tapped again on its root.
  final List<TabReselectHandlers> _reselectHandlers = List.generate(
    _tabCount,
    (_) => TabReselectHandlers(),
  );

  /// The Misék and the Térkép tab are told whether they are the one on
  /// screen, because the IndexedStack keeps them alive underneath the others
  /// and they refresh when they come back into view. None is while the
  /// Részletes kereső stands in their place.
  Widget _tab(int index) {
    final isActive = _selectedIndex == index && !_advancedSearchOpen;
    final tabBuilder = widget.tabBuilder;
    if (tabBuilder != null) return tabBuilder(index, isActive);
    switch (index) {
      case 0:
        return const ChurchesPage();
      case _massesTab:
        return _underSectionBar(
          'Mai misék',
          NearMassesPage(isActive: isActive),
        );
      default:
        return _underSectionBar('Térkép', MapPage(isActive: isActive));
    }
  }

  /// The Templomok tab's purple strip, with the tab's name in place of its
  /// Közeli / Kedvencek tabs.
  Widget _underSectionBar(String title, Widget page) {
    return Scaffold(appBar: SectionBar.title(title), body: page);
  }

  @override
  void initState() {
    super.initState();
    _prefetchFavorites();
  }

  /// Refreshes the favorites' data and schedules in the background; the
  /// screen does not wait for it.
  void _prefetchFavorites() {
    final favorites = Provider.of<FavoritesService>(context, listen: false);
    FavoritesPrefetch(
      onChurchesGone: favorites.removeAll,
    ).startWhenLoaded(favorites);
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) {
      _returnToTop(index);
    } else {
      // A search view left open would wait in the tab, keyboard and all.
      _activeNavigator?.popUntil((route) => route is! PopupRoute);
    }
    // Any tab, the selected one too, closes the Részletes kereső: no search
    // is left behind the tabs half done (spec 0010, „Keret").
    setState(() {
      _builtTabs.add(index);
      _selectedIndex = index;
      _advancedSearchName = null;
    });
  }

  /// The tab on screen tapped again (DESIGN.md NA4): from a deeper page back
  /// to its root, and on the root to the top of its list, unless one of its
  /// pages takes the tap first (the Templomok tab goes back to Közeli).
  void _returnToTop(int index) {
    final navigator = _tabNavigators[index].currentState;
    if (navigator == null) return;
    if (navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
      return;
    }
    // The tap closes the Részletes kereső; the list is not on screen yet.
    if (_advancedSearchOpen) return;
    if (_reselectHandlers[index].handle()) return;
    final rootContext = _tabRoots[index].currentContext;
    if (rootContext == null) return;
    final controller = PrimaryScrollController.maybeOf(rootContext);
    if (controller == null) return;
    final animate = !MediaQuery.disableAnimationsOf(rootContext);
    for (final position in controller.positions) {
      if (animate) {
        unawaited(
          position.animateTo(
            position.minScrollExtent,
            duration: Durations.medium3,
            curve: Easing.standard,
          ),
        );
      } else {
        position.jumpTo(position.minScrollExtent);
      }
    }
  }

  /// Back (DESIGN.md NA3) steps through the tab's own stack, then closes the
  /// Részletes kereső; from a tab's root it goes to the Templomok, and from
  /// there out of the app.
  void _goBack() {
    final navigator = _activeNavigator;
    if (navigator != null && navigator.canPop()) {
      unawaited(navigator.maybePop());
    } else if (_advancedSearchOpen) {
      _closeAdvancedSearch();
    } else if (_selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
    } else {
      unawaited(SystemNavigator.pop());
    }
  }

  /// Opens the Részletes kereső in the tab's place, with what the search bar
  /// held as the church's name.
  void _openAdvancedSearch(String name) {
    setState(() {
      _advancedSearchName = name;
      _advancedSearchRun++;
    });
  }

  void _closeAdvancedSearch() {
    if (!_advancedSearchOpen) return;
    setState(() => _advancedSearchName = null);
  }

  @override
  Widget build(BuildContext context) {
    // Never popped by the system: the tabs' stacks lie inside this route, so
    // [_goBack] decides, and leaves the app itself when nothing is left.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          sizing: StackFit.expand,
          children: List<Widget>.generate(
            _tabCount,
            (int index) =>
                _builtTabs.contains(index)
                    ? _tabNavigator(index)
                    : const SizedBox.shrink(),
          ),
        ),
        bottomNavigationBar: MiserendNavigationBar(
          destinations: const [
            // Neither the church nor the map has a rounded outline
            // (DESIGN.md IK2).
            MiserendDestination(
              icon: Icon(Icons.church_rounded),
              label: 'Templomok',
            ),
            // The app icon's chalice; tinted like the Material icons beside
            // it.
            MiserendDestination(
              icon: ImageIcon(AssetImage('assets/images/chalice.png')),
              label: 'Misék',
            ),
            MiserendDestination(icon: Icon(Icons.map_rounded), label: 'Térkép'),
            MiserendDestination(
              icon: Icon(Icons.info_outline_rounded),
              selectedIcon: Icon(Icons.info_rounded),
              label: 'Névjegy',
            ),
          ],
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onItemTapped,
        ),
      ),
    );
  }

  /// The tab's own stack. Its root page is rebuilt with the screen, so that
  /// it follows the Részletes kereső and the tab's [isActive].
  Widget _tabNavigator(int index) {
    return TabReselect(
      handlers: _reselectHandlers[index],
      child: Navigator(
        key: _tabNavigators[index],
        pages: [
          MaterialPage<void>(
            child:
                index == _aboutTab
                    ? KeyedSubtree(
                      key: _tabRoots[index],
                      child: Builder(
                        builder:
                            widget.aboutBuilder ??
                            (context) => const AboutPage(),
                      ),
                    )
                    : _tabRoot(index),
          ),
        ],
        // The root page is never popped: back from it is [_goBack]'s.
        onDidRemovePage: (_) {},
      ),
    );
  }

  /// The search bar over the tab, or over the Részletes kereső standing in
  /// its place; the tab stays alive underneath, as it does while another tab
  /// is on screen.
  Widget _tabRoot(int index) {
    final advancedSearchName =
        index == _selectedIndex ? _advancedSearchName : null;
    return Scaffold(
      key: _tabRoots[index],
      backgroundColor: Colors.white,
      appBar: AppBar(
        clipBehavior: Clip.none,
        iconTheme: IconThemeData(color: Colors.black54),
        title: _HomeSearchBar(
          suggestions: _suggestions,
          resultsLoader: widget.searchResultsLoader,
          onAdvancedSearch: _openAdvancedSearch,
          onSearchStarted: _closeAdvancedSearch,
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: advancedSearchName != null,
            child: TickerMode(
              enabled: advancedSearchName == null,
              child: _tab(index),
            ),
          ),
          if (advancedSearchName != null)
            AdvancedSearchPage(
              key: ValueKey(_advancedSearchRun),
              initialName: advancedSearchName,
              onClose: _closeAdvancedSearch,
              loader: widget.advancedSearchLoader,
              location: widget.location,
            ),
        ],
      ),
    );
  }
}

/// The search bar at the top of each tab, with its suggestions. Each tab has
/// its own, in the tab's own stack, so that the results open there.
class _HomeSearchBar extends StatefulWidget {
  const _HomeSearchBar({
    required this.suggestions,
    required this.resultsLoader,
    required this.onAdvancedSearch,
    required this.onSearchStarted,
  });

  final SearchSuggestions suggestions;

  /// Injected by tests; the results page builds its own otherwise.
  final ChurchListLoader? resultsLoader;

  /// Told what the bar held when the Részletes kereső row was chosen.
  final ValueChanged<String> onAdvancedSearch;

  /// Told before a search is submitted or a suggestion opens: it stands in
  /// the Részletes kereső's place.
  final VoidCallback onSearchStarted;

  @override
  State<_HomeSearchBar> createState() => _HomeSearchBarState();
}

class _HomeSearchBarState extends State<_HomeSearchBar> {
  final SearchController _searchController = SearchController();

  List<Suggestion> suggestions = <Suggestion>[];

  Timer? _searchDebounce;

  /// Bumped per search so a slow query cannot overwrite newer suggestions.
  int _searchRequestId = 0;

  static const double _searchBarHeight = 48;
  static const double _searchViewMaxHeight = 360;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _openAdvancedSearch() {
    final name = _searchController.text;
    _clearSearchBar();
    widget.onAdvancedSearch(name);
  }

  /// A search is submitted or a suggestion chosen.
  void _onBarSearchStarted() {
    widget.onSearchStarted();
    _clearSearchBar();
  }

  /// Any search from the bar empties it: it opens empty next time, not with
  /// the last search's text and suggestions (spec 0010, „Belépés").
  void _clearSearchBar() {
    _searchDebounce?.cancel();
    // A search still running must not bring its suggestions back.
    _searchRequestId++;
    if (_searchController.isOpen) _searchController.closeView('');
    _searchController.clear();
    setState(suggestions.clear);
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeFocus(
      child: SizedBox(
        height: _searchBarHeight,
        child: SearchAnchor.bar(
          isFullScreen: false,
          // Opened, the view used to take the default 360 × 240 at least
          // and a taller header than the bar it opens from. It now keeps
          // the bar's width and height and grows with the suggestions,
          // up to a cap that leaves room for the keyboard.
          viewHeaderHeight: _searchBarHeight,
          // A minimum height makes the view build its list even with no
          // suggestions, so that the Részletes kereső row is always there.
          viewConstraints: const BoxConstraints(
            minHeight: _searchBarHeight,
            maxHeight: _searchViewMaxHeight,
          ),
          shrinkWrap: true,
          viewBuilder:
              (suggestions) => SearchSuggestionList(
                suggestions: suggestions,
                footer: _advancedSearchRow(),
              ),
          onChanged: _onSearchChanged,
          onSubmitted: _onSearchSubmitted,
          searchController: _searchController,
          suggestionsBuilder: (
            BuildContext context,
            SearchController controller,
          ) {
            return List<Widget>.generate(suggestions.length, (int index) {
              return suggestions[index].buildWidget(context);
            });
          },
        ),
      ),
    );
  }

  /// The last row of the suggestions, whatever is typed (spec 0010,
  /// „Belépés"): the Android app's advanced search stood in the same place,
  /// under the same name.
  Widget _advancedSearchRow() {
    return ListTile(
      onTap: _openAdvancedSearch,
      titleAlignment: ListTileTitleAlignment.center,
      leading: const AspectRatio(
        aspectRatio: 1,
        child: Icon(Icons.manage_search, color: Colors.black54, size: 24.0),
      ),
      title: const Text('Részletes kereső'),
    );
  }

  /// Each keystroke used to run two wildcard scans over every church.
  /// Waiting for a pause in typing collapses a typed word into one search.
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchRequestId++;
    if (value.length > 2) {
      _searchDebounce = Timer(
        const Duration(milliseconds: 250),
        () => _runSearch(value),
      );
    } else {
      setState(() {
        suggestions.clear();
        _refreshSuggestionList();
      });
    }
  }

  Future<void> _runSearch(String value) async {
    final int requestId = _searchRequestId;
    final found = await widget.suggestions.suggest(value);
    final combined = <Suggestion>[];
    combined.addAll(
      found.churches.map(
        (c) => ChurchSuggestion(c, onChosen: _onBarSearchStarted),
      ),
    );
    combined.addAll(
      found.cities.map(
        (c) => CitySuggestion(
          c,
          onChosen: _onBarSearchStarted,
          resultsLoader: widget.resultsLoader,
        ),
      ),
    );
    if (!mounted || requestId != _searchRequestId) {
      return;
    }
    setState(() {
      suggestions = combined;
      _refreshSuggestionList();
    });
  }

  /// Nudges the search controller so the open suggestion list rebuilds.
  void _refreshSuggestionList() {
    final value = _searchController.text;
    _searchController.text = '';
    _searchController.text = value;
  }

  void _onSearchSubmitted(String value) {
    _onBarSearchStarted();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => SearchResultsPage(
              searchParams: SearchParams.fromSearchTerm(value),
              loader: widget.resultsLoader,
            ),
      ),
    );
  }
}
