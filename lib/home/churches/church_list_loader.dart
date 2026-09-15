import 'package:miserend/api/api_result.dart';
import 'package:miserend/api/cache_write_through.dart';
import 'package:miserend/api/miserend_api_client.dart';
import 'package:miserend/database/cache/cache_database.dart';
import 'package:miserend/database/cache/church_list_entry.dart';

/// What a church list screen draws: the rows, whether the last refresh got
/// no answer, and how old the data is (ADR-0003).
class ChurchList {
  const ChurchList({
    required this.churches,
    required this.failure,
    required this.dataAsOf,
  });

  final List<ChurchListEntry> churches;

  /// Why the last refresh got no answer; null before one has finished and
  /// after one succeeded.
  final ApiFailure? failure;

  /// The list's last successful refresh, or the bootstrap import before one.
  final DateTime? dataAsOf;
}

/// One screen's list: how it reads the cache, and which API call refreshes
/// it.
abstract class ChurchListQuery {
  const ChurchListQuery();

  /// Names the screen, whose last successful refresh is stored under it.
  String get syncKey;

  Future<List<ChurchListEntry>> read(CacheDatabase cache, DateTime today);

  /// The background call, given the rows the screen shows.
  Future<ApiResult<ChurchesResponse>> fetch(
      MiserendApiClient api, List<ChurchListEntry> shown);
}

/// The Közeli templomok list: every church, nearest first, refreshed from
/// the hundred nearest the API knows.
class NearChurchesQuery extends ChurchListQuery {
  const NearChurchesQuery({required this.lat, required this.lon});

  final double lat;
  final double lon;

  @override
  String get syncKey => 'list:near';

  @override
  Future<List<ChurchListEntry>> read(CacheDatabase cache, DateTime today) =>
      cache.nearChurches(lat, lon, today);

  @override
  Future<ApiResult<ChurchesResponse>> fetch(
          MiserendApiClient api, List<ChurchListEntry> shown) =>
      api.fetchNearbyChurches(lat: lat, lon: lon);
}

/// The Kedvencek list: the favorite churches, refreshed by id.
class FavoritesQuery extends ChurchListQuery {
  const FavoritesQuery(this.ids);

  final List<int> ids;

  @override
  String get syncKey => 'list:favorites';

  @override
  Future<List<ChurchListEntry>> read(CacheDatabase cache, DateTime today) =>
      cache.churchesByIds(ids, today);

  @override
  Future<ApiResult<ChurchesResponse>> fetch(
          MiserendApiClient api, List<ChurchListEntry> shown) =>
      api.fetchChurches(ids);
}

/// The Keresés results: churches by a part of their name, or the churches of
/// a city. The found churches are refreshed by id; when the cache finds
/// nothing, the API's search is asked for churches the cache does not know.
class SearchQuery extends ChurchListQuery {
  const SearchQuery.byName(String this.term) : city = null;

  const SearchQuery.byCity(String this.city) : term = null;

  /// A part of the name or common name; null when searching a city.
  final String? term;

  /// The whole name of a city; null when searching by name.
  final String? city;

  /// The most churches refreshed by id; the rest show the cache.
  static const int refreshLimit = 100;

  @override
  String get syncKey => 'list:search';

  @override
  Future<List<ChurchListEntry>> read(CacheDatabase cache, DateTime today) {
    final city = this.city;
    return city != null
        ? cache.churchesInCity(city, today)
        : cache.searchChurches(term!, today);
  }

  @override
  Future<ApiResult<ChurchesResponse>> fetch(
      MiserendApiClient api, List<ChurchListEntry> shown) {
    if (shown.isEmpty) return api.searchChurches(city ?? term!);
    return api.fetchChurches(
        shown.take(refreshLimit).map((church) => church.id).toList());
  }
}

/// Supplies the church lists: first from the cache, then again once the
/// API's answer has been written through to it. It lives outside the pages
/// so that they can be pumped against a fake.
class ChurchListLoader {
  ChurchListLoader({
    CacheDatabase? cache,
    MiserendApiClient? api,
    this.clock = DateTime.now,
    this.onChurchesGone,
  })  : _cache = cache,
        _api = api ?? MiserendApiClient();

  CacheDatabase? _cache;
  final MiserendApiClient _api;
  final DateTime Function() clock;

  /// Told when an answer reports churches removed from miserend.hu.
  final ChurchesGone? onChurchesGone;

  Future<CacheDatabase> _db() async => _cache ??= await CacheDatabase.create();

  /// What the cache holds now, without asking the API.
  Future<ChurchList> load(ChurchListQuery query) async {
    final cache = await _db();
    return ChurchList(
      churches: await query.read(cache, clock()),
      failure: null,
      dataAsOf: await _dataAsOf(cache, query),
    );
  }

  /// Asks the API, writes the answer through and reads the list again. A
  /// failed call leaves the cache and the [shown] rows as they are, and says
  /// which way it failed.
  Future<ChurchList> refresh(
      ChurchListQuery query, List<ChurchListEntry> shown) async {
    final cache = await _db();
    final now = clock();

    switch (await query.fetch(_api, shown)) {
      case ApiFailed(:final failure):
        return ChurchList(
          churches: shown,
          failure: failure,
          dataAsOf: await _dataAsOf(cache, query),
        );
      case ApiSuccess(:final value):
        await CacheWriteThrough(cache, onChurchesGone: onChurchesGone)
            .write(value, today: now, minimal: true);
        await cache.setSyncTime(query.syncKey, now);
        return ChurchList(
          churches: await query.read(cache, now),
          failure: null,
          dataAsOf: now,
        );
    }
  }

  Future<DateTime?> _dataAsOf(CacheDatabase cache, ChurchListQuery query) async =>
      await cache.syncTime(query.syncKey) ?? await cache.bootstrappedAt();
}
