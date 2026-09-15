import 'package:miserend/database/cache/cache_database.dart';
import 'package:miserend/database/cache/church_list_entry.dart';

/// What the search bar offers while typing: churches and cities.
class Suggestions {
  const Suggestions({required this.churches, required this.cities});

  final List<ChurchListEntry> churches;
  final List<String> cities;
}

/// Reads the search bar's suggestions from the cache. It is deliberately
/// built without an API client: the suggestions follow every pause in typing,
/// and must not wait for the network (spec 0005, „Keresés — javaslatok").
class SearchSuggestions {
  /// Churches offered at once; the results page lists them all.
  static const int churchLimit = 20;

  SearchSuggestions({CacheDatabase? cache}) : _cache = cache;

  CacheDatabase? _cache;

  Future<Suggestions> suggest(String term) async {
    final cache = _cache ??= await CacheDatabase.create();
    final churches = await cache.searchChurches(term, null);
    return Suggestions(
      churches: churches.take(churchLimit).toList(),
      cities: await cache.searchCities(term),
    );
  }
}
