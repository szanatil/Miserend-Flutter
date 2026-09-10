import 'package:miserend/api/miserend_api_client.dart';
import 'package:miserend/database/cache/cache_database.dart';
import 'package:miserend/database/cache/cached_mass.dart';
import 'package:miserend/database/church.dart';

/// Supplies the church details page with a day-by-day schedule: first from the
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
  /// earlier visit's API response.
  Future<List<List<CachedMass>>> loadCached(int churchId, DateTime today) async {
    final cache = await _db();
    final cached = await cache.getMassesForChurch(
      churchId,
      from: today,
      until: today.add(const Duration(days: scheduleDays)),
    );
    return _groupByDay(cached, today);
  }

  /// Asks the API, writes what it gets through to the cache, and returns the
  /// schedule again. Failures are silent: this is a read, and a stale schedule
  /// beats an error message on a page that already shows one.
  Future<List<List<CachedMass>>> refresh(Church church, DateTime today) async {
    final cache = await _db();

    final details = await _api.fetchChurch(church.id);
    if (details != null) {
      await cache.upsertChurch(details);
    }

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
      // is already cached is kept rather than wiped.
      if (fresh.isNotEmpty) {
        await cache.replaceMassesForChurch(church.id, fresh);
      }
    }

    return loadCached(church.id, today);
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
