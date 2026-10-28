import 'package:flutter/foundation.dart';
import 'package:miserend/api/api_result.dart';
import 'package:miserend/home/search_suggestions.dart';

/// Offers nothing, so that no test reads the device's cache.
class NoSearchSuggestions extends SearchSuggestions {
  /// Whether the bootstrap import has run; it has, unless a test says not.
  final ValueNotifier<bool> bootstrapFlag = ValueNotifier(true);

  /// How the app's last API call ended, as the bar is told.
  final ValueNotifier<ApiFailure?> connection = ValueNotifier(null);

  @override
  ValueListenable<bool> get bootstrapped => bootstrapFlag;

  @override
  ValueListenable<ApiFailure?> get lastFailure => connection;

  @override
  Future<Suggestions> suggest(String term) async =>
      const Suggestions(churches: [], cities: []);
}
