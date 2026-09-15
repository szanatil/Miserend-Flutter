import 'package:miserend/api/api_result.dart';
import 'package:miserend/api/cache_write_through.dart';
import 'package:miserend/api/miserend_api_client.dart';
import 'package:miserend/database/cache/cache_database.dart';
import 'package:miserend/database/cache/church_list_entry.dart';
import 'package:miserend/database/cache/church_location.dart';

/// What a church list screen draws: the rows, whether the last refresh got
/// no answer, and how old the data is (ADR-0003).
class ChurchList {
  const ChurchList({
    required this.churches,
    required this.failure,
    required this.dataAsOf,
    this.removed = const [],
  });

  final List<ChurchListEntry> churches;

  /// Why the last refresh got no answer; null before one has finished and
  /// after one succeeded.
  final ApiFailure? failure;

  /// The list's last successful refresh, or the bootstrap import before one.
  final DateTime? dataAsOf;

  /// Churches the refresh found removed from miserend.hu, and deleted.
  final List<int> removed;
}

/// One screen's list: how it reads the cache, and which API call refreshes
/// it.
abstract class ChurchListQuery {
  const ChurchListQuery();

  /// Names the screen, whose last successful refresh is stored under it.
  String get syncKey;

  /// Whether the background call's answer leaves fields out.
  bool get minimal => true;

  Future<List<ChurchListEntry>> read(CacheDatabase cache, DateTime today);

  /// When the data shown was last refreshed, or null if never.
  Future<DateTime?> lastRefreshed(CacheDatabase cache) =>
      cache.syncTime(syncKey);

  Future<void> markRefreshed(CacheDatabase cache, DateTime now) =>
      cache.setSyncTime(syncKey, now);

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

/// The map's church card: one church, refreshed in full — photos and
/// description too, which also warms up its details page. How old it is, is
/// the church's own last sync rather than a screen's.
class ChurchCardQuery extends ChurchListQuery {
  const ChurchCardQuery(this.churchId);

  final int churchId;

  @override
  String get syncKey => 'card:$churchId';

  @override
  bool get minimal => false;

  @override
  Future<List<ChurchListEntry>> read(CacheDatabase cache, DateTime today) =>
      cache.churchesByIds([churchId], today);

  @override
  Future<DateTime?> lastRefreshed(CacheDatabase cache) async =>
      (await cache.getChurch(churchId))?.localSyncedAt;

  /// The write itself stamps the church's sync time.
  @override
  Future<void> markRefreshed(CacheDatabase cache, DateTime now) async {}

  @override
  Future<ApiResult<ChurchesResponse>> fetch(
          MiserendApiClient api, List<ChurchListEntry> shown) =>
      api.fetchChurches([churchId], length: ResponseLength.full);
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
            .write(value, today: now, minimal: query.minimal);
        await query.markRefreshed(cache, now);
        return ChurchList(
          churches: await query.read(cache, now),
          failure: null,
          dataAsOf: now,
          removed: value.missing,
        );
    }
  }

  /// Every church with a position, for the map's markers.
  Future<List<ChurchLocation>> churchLocations() async =>
      (await _db()).churchLocations();

  Future<DateTime?> _dataAsOf(CacheDatabase cache, ChurchListQuery query) async =>
      await query.lastRefreshed(cache) ?? await cache.bootstrappedAt();
}
