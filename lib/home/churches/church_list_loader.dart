import 'package:miserend/database/cache/cache_database.dart';
import 'package:miserend/database/cache/church_list_entry.dart';

/// Supplies the church lists from the cache. It lives outside the pages so
/// that they can be pumped against a fake.
class ChurchListLoader {
  ChurchListLoader({CacheDatabase? cache, this.clock = DateTime.now})
      : _cache = cache;

  CacheDatabase? _cache;
  final DateTime Function() clock;

  Future<CacheDatabase> _db() async => _cache ??= await CacheDatabase.create();

  /// Every church with a position, nearest first, with today's rows.
  Future<List<ChurchListEntry>> nearChurches(double lat, double lon) async {
    return (await _db()).nearChurches(lat, lon, clock());
  }
}
