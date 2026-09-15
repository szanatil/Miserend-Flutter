import 'package:flutter/foundation.dart';
import 'package:miserend/api/api_result.dart';
import 'package:miserend/api/cache_write_through.dart';
import 'package:miserend/api/miserend_api_client.dart';
import 'package:miserend/church_details/church_schedule_loader.dart';
import 'package:miserend/database/cache/cache_database.dart';

/// Keeps the favorite churches' data and 20-day schedule in the cache, so that
/// they are there weeks later without signal (spec 0005, „Kedvencek
/// előfrissítése"). Runs at startup, at most once a day, and says nothing
/// either way.
class FavoritesPrefetch {
  /// The least time between two successful runs.
  static const Duration interval = Duration(hours: 24);

  static const String _syncKey = 'favorites:prefetch';

  FavoritesPrefetch({
    CacheDatabase? cache,
    MiserendApiClient? api,
    this.clock = DateTime.now,
    this.onChurchesGone,
  })  : _cache = cache,
        _api = api ?? MiserendApiClient();

  CacheDatabase? _cache;
  final MiserendApiClient _api;
  final DateTime Function() clock;

  /// Told when a favorite has been removed from miserend.hu.
  final ChurchesGone? onChurchesGone;

  /// Refreshes [favoriteIds] unless a run succeeded within [interval]. Any
  /// failure ends the run quietly without counting it, so the next start
  /// tries again.
  Future<void> runIfDue(List<int> favoriteIds) async {
    try {
      await _run(favoriteIds);
    } catch (error) {
      debugPrint('Favorites prefetch failed: $error');
    }
  }

  Future<void> _run(List<int> favoriteIds) async {
    if (favoriteIds.isEmpty) return;
    final cache = _cache ??= await CacheDatabase.create();
    final now = clock();
    final lastRun = await cache.syncTime(_syncKey);
    if (lastRun != null && now.difference(lastRun) < interval) return;

    final ChurchesResponse response;
    switch (await _api.fetchChurches(favoriteIds)) {
      case ApiFailed():
        return;
      case ApiSuccess(:final value):
        response = value;
    }
    await CacheWriteThrough(cache, onChurchesGone: onChurchesGone)
        .write(response, today: now, minimal: true);

    final today = DateTime(now.year, now.month, now.day);
    for (final id in favoriteIds) {
      if (response.missing.contains(id)) continue;
      final church = await cache.getChurch(id);
      final lat = church?.lat;
      final lon = church?.lon;
      if (lat == null || lon == null) continue;

      final masses = await _api.fetchMassesForChurch(
        churchId: id,
        lat: lat,
        lon: lon,
        from: today,
        until: today.add(const Duration(days: ChurchScheduleLoader.scheduleDays)),
      );
      switch (masses) {
        case ApiFailed():
          // The connection is likely gone for the rest as well; waiting out a
          // timeout per favorite would only hold the phone's radio awake.
          return;
        case ApiSuccess(:final value):
          await cache.replaceMassesForChurch(id, value);
      }
    }

    await cache.setSyncTime(_syncKey, now);
  }
}
