import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miserend/api/miserend_api_client.dart';
import 'package:miserend/database/cache/bootstrap_importer.dart';
import 'package:miserend/database/cache/cache_database.dart';
import 'package:miserend/menu/church_of_the_day_loader.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A church as the bootstrap import leaves it: no description.
Future<void> _importChurches(CacheDatabase cache, List<int> ids) =>
    cache.importChurches([
      for (final id in ids)
        BootstrapImporter.churchFromLegacyRow({
          'tid': id,
          'nev': 'Templom $id',
          'varos': 'Budapest',
        }),
    ], const []);

/// Answers the church call with the recorded church 38 and counts the calls.
class _Api {
  int calls = 0;
  bool offline = false;

  MiserendApiClient get client => MiserendApiClient(
    client: MockClient((request) async {
      calls++;
      if (offline) throw const SocketException('offline');
      final church =
          jsonDecode(File('test/fixtures/church_38.json').readAsStringSync())
                as Map<String, dynamic>
            ..remove('error');
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'templomok': [church],
            'hianyzo': [],
            'error': 0,
          }),
        ),
        200,
      );
    }),
  );
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late CacheDatabase cache;

  setUp(() async {
    cache = await CacheDatabase.create(path: inMemoryDatabasePath);
  });

  tearDown(() async => cache.db.close());

  group('loadCached', () {
    test('picks the same church all day', () async {
      await _importChurches(cache, List.generate(50, (i) => i + 1));
      final loader = ChurchOfTheDayLoader(cache: cache, api: _Api().client);

      final morning = await loader.loadCached(DateTime(2026, 9, 17, 6, 0));
      final evening = await loader.loadCached(DateTime(2026, 9, 17, 23, 0));

      expect(morning, isNotNull);
      expect(evening?.id, morning?.id);
    });

    test('picks another church on other days', () async {
      await _importChurches(cache, List.generate(50, (i) => i + 1));
      final loader = ChurchOfTheDayLoader(cache: cache, api: _Api().client);

      final ids = {
        for (var day = 1; day <= 10; day++)
          (await loader.loadCached(DateTime(2026, 9, day)))?.id,
      };

      expect(ids.length, greaterThan(1));
    });

    test('is null with an empty cache', () async {
      final loader = ChurchOfTheDayLoader(cache: cache, api: _Api().client);

      expect(await loader.loadCached(DateTime(2026, 9, 17)), isNull);
    });
  });

  group('refresh', () {
    test('writes the full answer through and reads the description', () async {
      await _importChurches(cache, [38]);
      final api = _Api();
      final loader = ChurchOfTheDayLoader(cache: cache, api: api.client);
      final cached = await loader.loadCached(DateTime(2026, 9, 17));
      expect(cached?.description, isNull);

      final fresh = await loader.refresh(cached!, DateTime(2026, 9, 17));

      expect(api.calls, 1);
      expect(fresh.description, contains('Főpl'));
      expect(fresh.street, 'Március 15. tér');
      expect((await cache.getChurch(38))?.description, fresh.description);
    });

    test('keeps the cached church when the call fails', () async {
      await _importChurches(cache, [38]);
      final api = _Api()..offline = true;
      final loader = ChurchOfTheDayLoader(cache: cache, api: api.client);
      final cached = await loader.loadCached(DateTime(2026, 9, 17));

      final fresh = await loader.refresh(cached!, DateTime(2026, 9, 17));

      expect(fresh.name, 'Templom 38');
      expect(fresh.description, isNull);
    });
  });
}
