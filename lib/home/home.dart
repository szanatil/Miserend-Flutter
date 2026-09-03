import 'dart:async';

import 'package:flutter/material.dart';
import 'package:miserend/home/churches/churches_page.dart';
import 'package:miserend/home/churches/search_results.dart';
import 'package:miserend/home/masses/near_masses_page.dart';
import 'package:miserend/home/map/map_page.dart';
import 'package:miserend/widgets/photo_decode.dart';

import '../church_details/church_details_page.dart';
import '../database/church.dart';
import '../database/miserend_database.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

abstract class Suggestion {
  Widget buildWidget(BuildContext context);
}

class ChurchSuggestion extends Suggestion
{
  static const double _thumbnailSize = 40;

  Church church;

  ChurchSuggestion(this.church);

  Widget _errorBuilder(
      BuildContext context, Object error, StackTrace? stackTrace) {
    return Image.asset('assets/images/church_blurred.png',
        fit: BoxFit.cover,
        cacheHeight: PhotoDecode.forSlot(context, _thumbnailSize));
  }

  @override
  Widget buildWidget(BuildContext context) {
    return ListTile(
        onTap: () {
          _openDetails(church, context);
        },
        titleAlignment: ListTileTitleAlignment.center,
        leading:  AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: FadeInImage.assetNetwork(
              fit: BoxFit.cover,
              placeholder: 'assets/images/church_blurred.png',
              image: church.imageUrl ?? "",
              imageErrorBuilder: _errorBuilder,
              imageCacheHeight: PhotoDecode.forSlot(context, _thumbnailSize),
              placeholderCacheHeight:
                  PhotoDecode.forSlot(context, _thumbnailSize),
            ),
          ),
        ),
        title: Text(church.name ?? "")
    );
  }

  _openDetails(Church church, BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => ChurchDetailsPage(church: church)),
    );
  }
}

class CitySuggestion extends Suggestion {

  String cityName = "";

  CitySuggestion(this.cityName);

  @override
  Widget buildWidget(BuildContext context) {
    return ListTile(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
          builder: (context) => SearchResultsPage(searchParams: SearchParams.fromCity(cityName))),
        );
      },
        titleAlignment: ListTileTitleAlignment.center,
        leading:  AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Icon(
              Icons.location_city,
              color: Colors.black54,
              size: 24.0,
            ),
          ),
        ),
        title: Text(cityName)
    );
  }

}


class _HomeScreenState extends State<HomeScreen> {

  final SearchController _searchController = SearchController();
  int _selectedIndex = 0;

  List<Suggestion> suggestions = <Suggestion>[];

  Timer? _searchDebounce;

  /// Bumped per search so a slow query cannot overwrite newer suggestions.
  int _searchRequestId = 0;

  /// Tabs that have been opened at least once. Switching tabs used to drop the
  /// page out of the tree entirely, so coming back re-ran the all-churches
  /// query and asked for the location again. They are kept alive once built,
  /// and pages never opened are not built at all, so startup is unchanged.
  final Set<int> _builtTabs = <int>{0};

  static const List<Widget> _widgetOptions = <Widget>[
    ChurchesPage(),
    NearMassesPage(),
    MapPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _builtTabs.add(index);
      _selectedIndex = index;
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        clipBehavior: Clip.none,
        iconTheme:  IconThemeData(
            color: Colors.black54
        ),
        title: ExcludeFocus(
          child: SizedBox(
            height: 48,
            child: SearchAnchor.bar(
              isFullScreen: false,
              onChanged: _onSearchChanged,
              onSubmitted: _onSearchSubmitted,
              searchController: _searchController,
              suggestionsBuilder: (BuildContext context, SearchController controller) {
                return List<Widget>.generate(suggestions.length, (int index) {
                  return suggestions[index].buildWidget(context);
                });
              },
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        sizing: StackFit.expand,
        children: List<Widget>.generate(
          _widgetOptions.length,
          (int index) => _builtTabs.contains(index)
              ? _widgetOptions[index]
              : const SizedBox.shrink(),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.church),
            label: 'Templomok',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule),
            label: 'Misék',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Térkép',
          ),
        ],
        currentIndex: _selectedIndex,
        backgroundColor: Theme.of(context).primaryColor,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white54,
        onTap: _onItemTapped,
      ),
    );
  }

  /// Each keystroke used to run two wildcard scans over all 5000 churches.
  /// Waiting for a pause in typing collapses a typed word into one search.
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchRequestId++;
    if (value.length > 2) {
      _searchDebounce = Timer(
          const Duration(milliseconds: 250), () => _runSearch(value));
    } else {
      setState(() {
        suggestions.clear();
        _refreshSuggestionList();
      });
    }
  }

  Future<void> _runSearch(String value) async {
    final int requestId = _searchRequestId;
    MiserendDatabase db = await MiserendDatabase.create();
    var churches = await db.getChurchesForSearchTerm(value);
    var cities = await db.getCitiesForSearchTerm(value);
    var combined = <Suggestion>[];
    combined.addAll(churches.take(20).map((c) => ChurchSuggestion(c)));
    combined.addAll(cities.map((c) => CitySuggestion(c)));
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
    var value = _searchController.text;
    _searchController.text = "";
    _searchController.text = value;
  }

  void _onSearchSubmitted(String value) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => SearchResultsPage(searchParams: SearchParams.fromSearchTerm(value))),
    );
  }
}