import 'package:miserend/api/api_result.dart';
import 'package:miserend/api/cache_write_through.dart';
import 'package:miserend/api/miserend_api_client.dart';
import 'package:miserend/church_details/church_page_data.dart';
import 'package:miserend/database/cache/cache_database.dart';
import 'package:miserend/database/cache/cached_mass.dart';
import 'package:miserend/database/cache/church_details.dart';
import 'package:miserend/database/church.dart';

/// Supplies the church details page with everything it draws: first from the
/// cache, then again once the API has answered. It lives outside the page so
/// that it can be tested without a widget tree.
class ChurchScheduleLoader {
  /// Today plus the days the page's horizontal strip shows.
  static const int scheduleDays = 20;

  ChurchScheduleLoader({
    CacheDatabase? cache,
    MiserendApiClient? api,
    this.onChurchesGone,
  }) : _cache = cache,
       _api = api ?? MiserendApiClient();

  CacheDatabase? _cache;
  final MiserendApiClient _api;

  /// Told when the API reports the church removed from miserend.hu.
  final ChurchesGone? onChurchesGone;

  Future<CacheDatabase> _db() async => _cache ??= await CacheDatabase.create();

  /// What the cache holds right now — the bootstrap import's rows, or an
  /// earlier visit's API response. Confession is never reported from here:
  /// see [ChurchPageData.confessionLive].
  Future<ChurchPageData> loadCached(int churchId, DateTime today) async {
    return _read(
      churchId,
      today,
      scheduleIsFresh: false,
      confessionLive: false,
      failure: null,
    );
  }

  /// Asks the API, writes what it gets through to the cache, and reads it back.
  /// A failed call leaves the cache as it is; the page data says which way it
  /// failed, so the page can mark what it shows as not live.
  Future<ChurchPageData> refresh(Church church, DateTime today) async {
    final cache = await _db();

    final churchResult = await _api.fetchChurches([
      church.id,
    ], length: ResponseLength.full);
    ChurchDetails? details;
    ApiFailure? churchFailure;
    switch (churchResult) {
      case ApiSuccess(:final value):
        await CacheWriteThrough(
          cache,
          onChurchesGone: onChurchesGone,
        ).write(value, today: today, minimal: false);
        if (value.missing.contains(church.id)) {
          return ChurchPageData(
            church: null,
            massesByDay: _groupByDay(const [], today),
            scheduleIsFresh: false,
            confessionLive: false,
            churchGone: true,
          );
        }
        for (final fresh in value.churches) {
          if (fresh.id == church.id) details = fresh;
        }
      case ApiFailed(:final failure):
        churchFailure = failure;
    }

    var scheduleIsFresh = false;
    ApiFailure? scheduleFailure;
    final lat = church.lat;
    final lon = church.lon;
    if (lat != null && lon != null) {
      final masses = await _api.fetchMassesForChurch(
        churchId: church.id,
        lat: lat,
        lon: lon,
        from: today,
        until: today.add(const Duration(days: scheduleDays)),
      );
      switch (masses) {
        case ApiSuccess(:final value):
          // An empty answer is an answer: the church holds no mass in the
          // window, and the stored schedule has to stop saying otherwise.
          await cache.replaceMassesForChurch(church.id, value);
          scheduleIsFresh = true;
        case ApiFailed(:final failure):
          scheduleFailure = failure;
      }
    }

    return _read(
      church.id,
      today,
      scheduleIsFresh: scheduleIsFresh,
      // Only a response from this call may light the confession tile.
      confessionLive: details?.hasConfession ?? false,
      failure: scheduleFailure ?? churchFailure,
    );
  }

  Future<ChurchPageData> _read(
    int churchId,
    DateTime today, {
    required bool scheduleIsFresh,
    required bool confessionLive,
    required ApiFailure? failure,
  }) async {
    final cache = await _db();
    final church = await cache.getChurch(churchId);
    final cached = await cache.getMassesForChurch(
      churchId,
      from: today,
      until: today.add(const Duration(days: scheduleDays)),
    );
    return ChurchPageData(
      church: church,
      massesByDay: _groupByDay(cached, today),
      scheduleIsFresh: scheduleIsFresh,
      confessionLive: confessionLive,
      failure: failure,
      dataAsOf: church?.localSyncedAt ?? await cache.bootstrappedAt(),
    );
  }

  /// One bucket per day, so that the day a mass belongs to is a list index.
  List<List<CachedMass>> _groupByDay(List<CachedMass> cached, DateTime today) {
    final days = List.generate(scheduleDays, (_) => <CachedMass>[]);
    for (final mass in cached) {
      final offset =
          DateTime(
            mass.time.year,
            mass.time.month,
            mass.time.day,
          ).difference(today).inDays;
      if (offset >= 0 && offset < days.length) {
        days[offset].add(mass);
      }
    }
    return days;
  }
}
