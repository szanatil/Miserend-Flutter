import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/database/cache/bootstrap_importer.dart';
import 'package:miserend/database/cache/cache_database.dart';
import 'package:miserend/home/search_suggestions.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late CacheDatabase cache;

  setUp(() async {
    cache = await CacheDatabase.create(path: inMemoryDatabasePath);
    await cache.importChurches([
      for (var id = 1; id <= 25; id++)
        BootstrapImporter.churchFromLegacyRow({
          'tid': id,
          'nev': 'Szent Mihály templom $id',
          'varos': id.isEven ? 'Szentendre' : 'Szentes',
        }),
      BootstrapImporter.churchFromLegacyRow({
        'tid': 1515,
        'nev': 'Budavári Nagyboldogasszony-templom',
        'ismertnev': 'Mátyás-templom',
        'varos': 'Budapest I. kerület',
      }),
    ], const []);
  });

  tearDown(() async => cache.db.close());

  // The loader is built on the cache alone: it has no API client to call.
  test('suggests churches by name and common name, from the cache', () async {
    final suggestions = await SearchSuggestions(cache: cache).suggest('Mátyás');

    expect(suggestions.churches.single.id, 1515);
    expect(suggestions.cities, isEmpty);
  });

  test('suggests at most twenty churches', () async {
    final suggestions = await SearchSuggestions(cache: cache).suggest('Mihály');

    expect(suggestions.churches, hasLength(20));
  });

  test('suggests the cities whose name contains the term', () async {
    final suggestions = await SearchSuggestions(cache: cache).suggest('Szent');

    expect(suggestions.cities, unorderedEquals(['Szentendre', 'Szentes']));
  });
}
