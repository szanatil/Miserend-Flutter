import 'package:miserend/home/search_suggestions.dart';

/// Offers nothing, so that no test reads the device's cache.
class NoSearchSuggestions extends SearchSuggestions {
  @override
  Future<Suggestions> suggest(String term) async =>
      const Suggestions(churches: [], cities: []);
}
