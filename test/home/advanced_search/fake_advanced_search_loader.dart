import 'package:miserend/api/api_result.dart';
import 'package:miserend/database/cache/church_list_entry.dart';
import 'package:miserend/home/advanced_search/advanced_search_loader.dart';

/// Answers each page with the page of [pages] at its index, and records what
/// was asked. A page past the end is empty with nothing more to come.
class FakeAdvancedSearchLoader extends AdvancedSearchLoader {
  FakeAdvancedSearchLoader(
    this.pages, {
    this.cityNames = const [],
    this.languageCodes = const [],
  });

  final List<AdvancedSearchResultPage> pages;
  final List<String> cityNames;
  final List<String> languageCodes;

  final List<(AdvancedSearchCriteria, int)> asked = [];

  @override
  Future<AdvancedSearchResultPage> loadPage(
    AdvancedSearchCriteria criteria,
    int page,
  ) async {
    asked.add((criteria, page));
    return page < pages.length ? pages[page] : resultPage(const []);
  }

  @override
  Future<List<String>> cities(String term) async => cityNames;

  @override
  Future<List<String>> languages() async => languageCodes;
}

AdvancedSearchResultPage resultPage(
  List<ChurchListEntry> churches, {
  bool hasMore = false,
  int? found,
  bool foundIsFinal = true,
  ApiFailure? failure,
}) => AdvancedSearchResultPage(
  churches: churches,
  hasMore: hasMore,
  found: found ?? churches.length,
  foundIsFinal: foundIsFinal,
  failure: failure,
  dataAsOf: null,
);

ChurchListEntry churchEntry(int id, {String? name}) => ChurchListEntry(
  id: id,
  name: name ?? 'Templom $id',
  commonName: null,
  city: 'Pécs',
  lat: 46.07,
  lon: 18.23,
  photo: null,
  masses: const [],
);
