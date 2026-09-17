import 'dart:math';

import 'package:miserend/api/api_result.dart';
import 'package:miserend/api/cache_write_through.dart';
import 'package:miserend/api/miserend_api_client.dart';
import 'package:miserend/database/cache/cache_database.dart';
import 'package:miserend/database/cache/church_details.dart';

/// Picks the Menü page's „Mai templom ajánlatunk": a random church of the
/// cache, the same one all day, so reopening the menu does not reshuffle it.
class ChurchOfTheDayLoader {
  ChurchOfTheDayLoader({
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

  /// The day's church as the cache holds it. The bootstrap import carries no
  /// description, so this is often without one until [refresh] (ADR-0003).
  Future<ChurchDetails?> loadCached(DateTime today) async {
    final cache = await _db();
    final count = await cache.churchCount();
    if (count == 0) return null;
    final day = DateTime.utc(today.year, today.month, today.day);
    final seed = day.difference(DateTime.utc(1970)).inDays;
    return cache.churchAt(Random(seed).nextInt(count));
  }

  /// Asks the API for the church in full, writes it through to the cache and
  /// reads it back. A failed call, or a church gone from miserend.hu, leaves
  /// [church] as it was: a recommendation needs no failure mark.
  Future<ChurchDetails> refresh(ChurchDetails church, DateTime today) async {
    final cache = await _db();
    final result = await _api.fetchChurches([
      church.id,
    ], length: ResponseLength.full);
    if (result case ApiSuccess(:final value)) {
      await CacheWriteThrough(
        cache,
        onChurchesGone: onChurchesGone,
      ).write(value, today: today, minimal: false);
    }
    return await cache.getChurch(church.id) ?? church;
  }
}
