import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miserend/about/church_of_the_day_loader.dart';
import 'package:miserend/api/miserend_api_client.dart';
import 'package:miserend/database/cache/bootstrap_importer.dart';
import 'package:miserend/database/cache/cache_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Churches as the bootstrap import leaves them: no description, and a photo
/// unless [photo] is false.
Future<void> _importChurches(
  CacheDatabase cache,
  List<int> ids, {
  bool photo = true,
}) => cache.importChurches([
  for (final id in ids)
    BootstrapImporter.churchFromLegacyRow({
      'tid': id,
      'nev': 'Templom $id',
      'varos': 'Budapest',
      if (photo) 'kep': 'https://miserend.hu/kepek/templomok/$id/a.jpg',
    }),
], const []);

/// Answers the church call with the recorded church 38, whatever was asked,
/// and records the ids of each call.
class _Api {
  final List<List<String>> calls = [];
  bool offline = false;

  MiserendApiClient get client => MiserendApiClient(
    client: MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      calls.add([for (final id in body['ids'] as List) '$id']);
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

    test('never picks a church without a photo', () async {
      await _importChurches(cache, [1, 2, 3], photo: false);
      await _importChurches(cache, [4]);
      final loader = ChurchOfTheDayLoader(cache: cache, api: _Api().client);

      for (var day = 1; day <= 5; day++) {
        expect((await loader.loadCached(DateTime(2026, 9, day)))?.id, 4);
      }
    });

    test('is null without a photographed church', () async {
      await _importChurches(cache, [1], photo: false);
      final loader = ChurchOfTheDayLoader(cache: cache, api: _Api().client);

      expect(await loader.loadCached(DateTime(2026, 9, 17)), isNull);
    });
  });

  group('refresh', () {
    test('asks for the candidates in one call and picks the one with a '
        'description', () async {
      await _importChurches(cache, [1, 2, 38]);
      final api = _Api();
      final loader = ChurchOfTheDayLoader(cache: cache, api: api.client);

      final fresh = await loader.refresh(DateTime(2026, 9, 17));

      expect(api.calls.single, unorderedEquals(['1', '2', '38']));
      expect(fresh?.id, 38);
      expect(fresh?.description, contains('Főpl'));
      expect(fresh?.street, 'Március 15. tér');
    });

    test('the cache then shows the same church at once', () async {
      await _importChurches(cache, [1, 2, 38]);
      final loader = ChurchOfTheDayLoader(cache: cache, api: _Api().client);
      await loader.refresh(DateTime(2026, 9, 17));

      final cached = await loader.loadCached(DateTime(2026, 9, 17, 20, 0));

      expect(cached?.id, 38);
      expect(cached?.description, isNotNull);
    });

    test('a failed call leaves the cached pick', () async {
      await _importChurches(cache, [38]);
      final api = _Api()..offline = true;
      final loader = ChurchOfTheDayLoader(cache: cache, api: api.client);

      final fresh = await loader.refresh(DateTime(2026, 9, 17));

      expect(fresh?.name, 'Templom 38');
      expect(fresh?.description, isNull);
    });
  });
}
