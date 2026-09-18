import 'dart:async';

import 'package:flutter/material.dart';
import 'package:miserend/database/cache/church_list_entry.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/favorites_prefetch.dart';
import 'package:miserend/home/advanced_search/advanced_search_loader.dart';
import 'package:miserend/home/advanced_search/advanced_search_page.dart';
import 'package:miserend/home/churches/church_card.dart';
import 'package:miserend/home/churches/churches_page.dart';
import 'package:miserend/home/churches/search_results.dart';
import 'package:miserend/home/map/map_page.dart';
import 'package:miserend/home/masses/near_masses_page.dart';
import 'package:miserend/home/search_suggestions.dart';
import 'package:miserend/home/widgets/search_suggestion_list.dart';
import 'package:miserend/home/widgets/section_bar.dart';
import 'package:miserend/location_provider.dart';
import 'package:miserend/menu/menu_page.dart';
import 'package:miserend/widgets/photo_decode.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.tabBuilder,
    this.suggestions,
    this.advancedSearchLoader,
    this.location,
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

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

abstract class Suggestion {
  Suggestion({required this.onChosen});

  /// Told before the suggestion opens what it offers: a search from the bar
  /// closes the Részletes kereső (spec 0010, „Belépés").
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

  CitySuggestion(this.cityName, {required super.onChosen});

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
  final SearchController _searchController = SearchController();
  int _selectedIndex = 0;

  List<Suggestion> suggestions = <Suggestion>[];

  Timer? _searchDebounce;

  late final SearchSuggestions _suggestions =
      widget.suggestions ?? SearchSuggestions();

  /// What the search bar held when the Részletes kereső was opened; null
  /// while it is closed.
  String? _advancedSearchName;

  /// Bumped each time the Részletes kereső opens, so that it starts over with
  /// empty conditions even when it was open already.
  int _advancedSearchRun = 0;

  bool get _advancedSearchOpen => _advancedSearchName != null;

  /// Bumped per search so a slow query cannot overwrite newer suggestions.
  int _searchRequestId = 0;

  /// Tabs that have been opened at least once. Switching tabs used to drop the
  /// page out of the tree entirely, so coming back re-ran the all-churches
  /// query and asked for the location again. They are kept alive once built,
  /// and pages never opened are not built at all, so startup is unchanged.
  final Set<int> _builtTabs = <int>{0};

  static const double _searchBarHeight = 48;
  static const double _searchViewMaxHeight = 360;

  static const int _tabCount = 3;
  static const int _massesTab = 1;

  /// The navigation item after the tabs. It opens the menu as a page of its
  /// own rather than a tab, so the tab on screen stays selected.
  static const int _menuItem = _tabCount;

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
    if (index == _menuItem) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MenuPage()),
      );
      return;
    }
    // Any tab, the selected one too, closes the Részletes kereső: no search
    // is left behind the tabs half done (spec 0010, „Keret").
    setState(() {
      _builtTabs.add(index);
      _selectedIndex = index;
      _advancedSearchName = null;
    });
  }

  /// Opens the Részletes kereső in the tab's place, with what the search bar
  /// holds as the church's name.
  void _openAdvancedSearch() {
    final name = _searchController.text;
    if (_searchController.isOpen) _searchController.closeView(name);
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
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final advancedSearchName = _advancedSearchName;
    return PopScope(
      canPop: !_advancedSearchOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeAdvancedSearch();
      },
      child: _scaffold(advancedSearchName),
    );
  }

  Widget _scaffold(String? advancedSearchName) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        clipBehavior: Clip.none,
        iconTheme: IconThemeData(color: Colors.black54),
        title: ExcludeFocus(
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
        ),
      ),
      // The Részletes kereső stands in the tab's place; the tabs stay alive
      // underneath, as they are when another tab is on screen.
      body: Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: advancedSearchName != null,
            child: TickerMode(
              enabled: advancedSearchName == null,
              child: IndexedStack(
                index: _selectedIndex,
                sizing: StackFit.expand,
                children: List<Widget>.generate(
                  _tabCount,
                  (int index) =>
                      _builtTabs.contains(index)
                          ? _tab(index)
                          : const SizedBox.shrink(),
                ),
              ),
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
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.church), label: 'Templomok'),
          // The app icon's chalice; tinted like the Material icons beside it.
          BottomNavigationBarItem(
            icon: ImageIcon(AssetImage('assets/images/chalice.png')),
            label: 'Misék',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Térkép'),
          BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'Menü'),
        ],
        // From four items Flutter switches to the shifting style, which would
        // drop the purple background and hide the inactive labels.
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        backgroundColor: Theme.of(context).primaryColor,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white54,
        onTap: _onItemTapped,
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
    final found = await _suggestions.suggest(value);
    final combined = <Suggestion>[];
    combined.addAll(
      found.churches.map(
        (c) => ChurchSuggestion(c, onChosen: _closeAdvancedSearch),
      ),
    );
    combined.addAll(
      found.cities.map(
        (c) => CitySuggestion(c, onChosen: _closeAdvancedSearch),
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
    _closeAdvancedSearch();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => SearchResultsPage(
              searchParams: SearchParams.fromSearchTerm(value),
            ),
      ),
    );
  }
}
