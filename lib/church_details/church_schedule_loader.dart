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

  ChurchScheduleLoader({CacheDatabase? cache, MiserendApiClient? api})
      : _cache = cache,
        _api = api ?? MiserendApiClient();

  CacheDatabase? _cache;
  final MiserendApiClient _api;

  Future<CacheDatabase> _db() async => _cache ??= await CacheDatabase.create();

  /// What the cache holds right now — the bootstrap import's rows, or an
  /// earlier visit's API response. Confession is never reported from here:
  /// see [ChurchPageData.confessionLive].
  Future<ChurchPageData> loadCached(int churchId, DateTime today) async {
    return _read(churchId, today,
        scheduleIsFresh: false, confessionLive: false);
  }

  /// Asks the API, writes what it gets through to the cache, and reads it back.
  /// Failures are silent: this is a read, and a stale page beats an error
  /// message on a page that already shows something.
  Future<ChurchPageData> refresh(Church church, DateTime today) async {
    final cache = await _db();

    final ChurchDetails? details = await _api.fetchChurch(church.id);
    if (details != null) {
      await cache.upsertChurch(details);
    }

    var scheduleIsFresh = false;
    final lat = church.lat;
    final lon = church.lon;
    if (lat != null && lon != null) {
      final fresh = await _api.fetchMassesForChurch(
        churchId: church.id,
        lat: lat,
        lon: lon,
        from: today,
        until: today.add(const Duration(days: scheduleDays)),
      );
      // An empty answer means either that the church holds no masses or that
      // the call failed, and the two are indistinguishable here — so whatever
      // is already cached is kept rather than wiped, and the schedule is not
      // claimed to be fresh.
      if (fresh.isNotEmpty) {
        await cache.replaceMassesForChurch(church.id, fresh);
        scheduleIsFresh = true;
      }
    }

    return _read(
      church.id,
      today,
      scheduleIsFresh: scheduleIsFresh,
      // Only a response from this call may light the confession tile.
      confessionLive: details?.hasConfession ?? false,
    );
  }

  Future<ChurchPageData> _read(
    int churchId,
    DateTime today, {
    required bool scheduleIsFresh,
    required bool confessionLive,
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
    );
  }

  /// One bucket per day, so that the day a mass belongs to is a list index.
  List<List<CachedMass>> _groupByDay(List<CachedMass> cached, DateTime today) {
    final days = List.generate(scheduleDays, (_) => <CachedMass>[]);
    for (final mass in cached) {
      final offset = DateTime(mass.time.year, mass.time.month, mass.time.day)
          .difference(today)
          .inDays;
      if (offset >= 0 && offset < days.length) {
        days[offset].add(mass);
      }
    }
    return days;
  }
}
