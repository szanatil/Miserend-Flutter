import 'package:flutter/foundation.dart';
import 'package:miserend/api/miserend_api_client.dart';
import 'package:miserend/database/cache/cache_database.dart';

/// Told which churches miserend.hu no longer has, so that whatever else
/// refers to them — the favorites — can let them go too.
typedef ChurchesGone = Future<void> Function(List<int> churchIds);

/// Writes an answer about churches through to the cache, the same way for
/// every screen: each church over its row, its `misek` over today's rows, and
/// the churches the `Church` endpoint reports missing out of the cache.
class CacheWriteThrough {
  const CacheWriteThrough(this.cache, {this.onChurchesGone});

  final CacheDatabase cache;
  final ChurchesGone? onChurchesGone;

  /// Told once an answer has changed the cached churches, whichever screen
  /// asked for it, so that the map can draw its markers again: a new church
  /// goes on the map as soon as any answer has written it (spec 0005,
  /// „Térkép").
  static Listenable get churchesWritten => _churchesWritten;
  static final ValueNotifier<int> _churchesWritten = ValueNotifier(0);

  /// [minimal] says the answer leaves fields out, which must not overwrite
  /// the cached ones.
  Future<void> write(
    ChurchesResponse response, {
    required DateTime today,
    required bool minimal,
  }) async {
    for (final church in response.churches) {
      await cache.upsertChurch(church, minimal: minimal);
      await cache.replaceDailyMasses(
        church.id,
        today,
        response.massesOf(church.id),
      );
    }
    // Only an explicit report counts: a search or nearby answer leaving a
    // church out says nothing about whether it still exists.
    if (response.missing.isNotEmpty) {
      await cache.deleteChurches(response.missing);
      await onChurchesGone?.call(response.missing);
    }
    if (response.churches.isNotEmpty || response.missing.isNotEmpty) {
      _churchesWritten.value++;
    }
  }
}
