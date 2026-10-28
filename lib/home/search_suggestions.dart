import 'package:flutter/foundation.dart';
import 'package:miserend/api/api_result.dart';
import 'package:miserend/api/api_status.dart';
import 'package:miserend/bootstrap/cache_bootstrap.dart';
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

  /// Whether the bootstrap import has run. Without it the cache knows only
  /// the churches some screen has loaded, so finding nothing may be why
  /// (spec 0015, „Tájékoztatás").
  ValueListenable<bool> get bootstrapped => CacheBootstrap.shared.done;

  /// How the app's last API call ended. Offline, finding nothing is not put
  /// down to the download (CONTEXT.md, „Nincs kapcsolat").
  ValueListenable<ApiFailure?> get lastFailure => ApiStatus.shared;

  Future<Suggestions> suggest(String term) async {
    final cache = _cache ??= await CacheDatabase.create();
    final churches = await cache.searchChurches(term, null);
    return Suggestions(
      churches: churches.take(churchLimit).toList(),
      cities: await cache.searchCities(term),
    );
  }
}
