import 'package:miserend/api/api_result.dart';
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

/// Supplies the church lists: first from the cache, then again once the
/// API's answer has been written through to it. It lives outside the pages
/// so that they can be pumped against a fake.
class ChurchListLoader {
  ChurchListLoader(
      {CacheDatabase? cache, MiserendApiClient? api, this.clock = DateTime.now})
      : _cache = cache,
        _api = api ?? MiserendApiClient();

  CacheDatabase? _cache;
  final MiserendApiClient _api;
  final DateTime Function() clock;

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
        await _writeThrough(cache, value, now);
        await cache.setSyncTime(query.syncKey, now);
        return ChurchList(
          churches: await query.read(cache, now),
          failure: null,
          dataAsOf: now,
        );
    }
  }

  /// Every church of a minimal answer over its cached row, and its `misek`
  /// over the cached rows of [today].
  Future<void> _writeThrough(
      CacheDatabase cache, ChurchesResponse response, DateTime today) async {
    for (final church in response.churches) {
      await cache.upsertChurch(church, minimal: true);
      await cache.replaceDailyMasses(
          church.id, today, response.massesOf(church.id));
    }
  }

  Future<DateTime?> _dataAsOf(CacheDatabase cache, ChurchListQuery query) async =>
      await cache.syncTime(query.syncKey) ?? await cache.bootstrappedAt();
}
