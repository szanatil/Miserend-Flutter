import 'dart:math';

import 'package:miserend/api/api_result.dart';
import 'package:miserend/api/cache_write_through.dart';
import 'package:miserend/api/miserend_api_client.dart';
import 'package:miserend/database/cache/cache_database.dart';
import 'package:miserend/database/cache/church_details.dart';
import 'package:miserend/widgets/miserend_text.dart';

/// Picks the Menü page's „Mai templom ajánlatunk": a random church with a
/// photo, the same one all day, so reopening the menu does not reshuffle it.
///
/// The bootstrap import carries no description, and not every church has one
/// on miserend.hu either. So the day has a short, fixed list of candidates,
/// and the first of them with a description wins.
class ChurchOfTheDayLoader {
  ChurchOfTheDayLoader({
    CacheDatabase? cache,
    MiserendApiClient? api,
    this.onChurchesGone,
  }) : _cache = cache,
       _api = api ?? MiserendApiClient();

  /// Enough for one with a description to be among them nearly always, and
  /// few enough for one full `Church` call to stay small.
  static const int _candidateCount = 10;

  CacheDatabase? _cache;
  final MiserendApiClient _api;

  /// Told when the API reports a candidate removed from miserend.hu.
  final ChurchesGone? onChurchesGone;

  Future<CacheDatabase> _db() async => _cache ??= await CacheDatabase.create();

  /// The day's church as the cache holds it: once [refresh] has run today,
  /// the same one it found.
  Future<ChurchDetails?> loadCached(DateTime today) async {
    final cache = await _db();
    return _best(cache, await _candidateIds(cache, today));
  }

  /// Asks the API for every candidate in full in one call, writes them through
  /// to the cache and picks again (ADR-0003). A failed call picks from the
  /// cache as it is: a recommendation needs no failure mark.
  Future<ChurchDetails?> refresh(DateTime today) async {
    final cache = await _db();
    final ids = await _candidateIds(cache, today);
    if (ids.isEmpty) return null;
    final result = await _api.fetchChurches(ids, length: ResponseLength.full);
    if (result case ApiSuccess(:final value)) {
      await CacheWriteThrough(
        cache,
        onChurchesGone: onChurchesGone,
      ).write(value, today: today, minimal: false);
    }
    return _best(cache, ids);
  }

  /// The day's candidates in the order they are preferred, from a random
  /// sequence seeded by the date.
  Future<List<int>> _candidateIds(CacheDatabase cache, DateTime today) async {
    final count = await cache.photographedChurchCount();
    final day = DateTime.utc(today.year, today.month, today.day);
    final random = Random(day.difference(DateTime.utc(1970)).inDays);
    final indexes = <int>{};
    while (indexes.length < min(count, _candidateCount)) {
      indexes.add(random.nextInt(count));
    }
    return [
      for (final index in indexes)
        if (await cache.photographedChurchAt(index) case final church?)
          church.id,
    ];
  }

  /// The first candidate with a description, or else the first one.
  Future<ChurchDetails?> _best(CacheDatabase cache, List<int> ids) async {
    ChurchDetails? first;
    for (final id in ids) {
      final church = await cache.getChurch(id);
      if (church == null) continue;
      if (!MiserendText.isEmpty(church.description)) return church;
      first ??= church;
    }
    return first;
  }
}
