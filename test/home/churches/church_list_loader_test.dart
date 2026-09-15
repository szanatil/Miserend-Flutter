import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miserend/api/api_result.dart';
import 'package:miserend/api/miserend_api_client.dart';
import 'package:miserend/database/cache/bootstrap_importer.dart';
import 'package:miserend/database/cache/cache_database.dart';
import 'package:miserend/database/cache/cached_mass.dart';
import 'package:miserend/home/churches/church_list_loader.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final DateTime _now = DateTime(2026, 9, 15, 12, 0);

/// A church answered by a list endpoint, with today's `misek`.
Map<String, Object?> _listed(int id, String name,
        {double lat = 47.50, List<(int, String)> masses = const []}) =>
    {
      'id': id,
      'nev': name,
      'ismertnev': null,
      'varos': 'Budapest',
      'orszag': 'Magyarország',
      'lat': lat,
      'lon': 19.04,
      'links': [],
      'adoraciok': [],
      'gyontatas': false,
      'frissitve': '2026-09-01 00:00:00',
      'misek': [
        for (final (hour, info) in masses)
          {
            'idopont': '2026-09-15 ${hour.toString().padLeft(2, '0')}:00:00',
            'informacio': info,
          }
      ],
    };

http.Response _json(Map<String, Object?> body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), 200);

/// Records every request and answers with [answer].
class _Api {
  _Api(this.answer);

  Future<http.Response> Function(http.Request request) answer;
  final List<http.Request> requests = [];

  MiserendApiClient get client => MiserendApiClient(
        client: MockClient((request) async {
          requests.add(request);
          return answer(request);
        }),
      );
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late CacheDatabase cache;

  setUp(() async {
    cache = await CacheDatabase.create(path: inMemoryDatabasePath);
    await cache.importChurches([
      BootstrapImporter.churchFromLegacyRow({
        'tid': 1,
        'nev': 'Régi név',
        'lat': 47.50,
        'lng': 19.04,
        'kep': 'https://miserend.hu/kepek/templomok/1/a.jpg',
      }),
    ], [
      CachedMass(
        id: null,
        apiMassId: null,
        churchId: 1,
        time: DateTime(2026, 9, 15, 8, 0),
        info: null,
        source: MassSource.bootstrap,
      ),
    ]);
    await cache.setBootstrappedAt(DateTime(2026, 8, 1, 10, 0));
  });

  tearDown(() async => cache.db.close());

  ChurchListLoader loaderWith(_Api api) =>
      ChurchListLoader(cache: cache, api: api.client, clock: () => _now);

  const near = NearChurchesQuery(lat: 47.50, lon: 19.04);

  group('load', () {
    test('reads the cache without asking the API', () async {
      final api = _Api((_) async => throw StateError('no call expected'));

      final list = await loaderWith(api).load(near);

      expect(list.churches.map((c) => c.name), ['Régi név']);
      expect(list.churches.single.masses.single.time,
          DateTime(2026, 9, 15, 8, 0));
      expect(list.failure, isNull);
      expect(api.requests, isEmpty);
    });

    test('dates the data to the bootstrap import before any refresh',
        () async {
      final list = await loaderWith(_Api((_) async => _json({}))).load(near);

      expect(list.dataAsOf, DateTime(2026, 8, 1, 10, 0));
    });
  });

  group('refresh near churches', () {
    test('asks NearBy around the position', () async {
      final api = _Api((_) async => _json({'templomok': [], 'error': 0}));

      await loaderWith(api).refresh(near, const []);

      expect(api.requests.single.url.path, '/api/v4/nearby');
      expect(jsonDecode(api.requests.single.body),
          containsPair('lat', 47.50));
    });

    test('writes the answer through and reads the list again', () async {
      final api = _Api((_) async => _json({
            'templomok': [
              _listed(1, 'Javított név',
                  masses: [(7, 'Római katolikus Szentmise')]),
              _listed(2, 'Új templom', lat: 47.51),
            ],
            'error': 0,
          }));

      final list = await loaderWith(api).refresh(near, const []);

      expect(list.failure, isNull);
      expect(list.churches.map((c) => c.name), ['Javított név', 'Új templom']);
      expect(list.churches.first.masses.map((m) => m.time),
          [DateTime(2026, 9, 15, 7, 0)]);
      // A minimal answer carries no photo; the cached one stays.
      expect(list.churches.first.photo,
          'https://miserend.hu/kepek/templomok/1/a.jpg');
    });

    test('dates the data to the successful refresh, for later loads too',
        () async {
      final api = _Api((_) async => _json({'templomok': [], 'error': 0}));
      final loader = loaderWith(api);

      final refreshed = await loader.refresh(near, const []);
      final later = await loader.load(near);

      expect(refreshed.dataAsOf, _now);
      expect(later.dataAsOf, _now);
    });

    test('no connection keeps what is shown and says so', () async {
      final api = _Api((_) async => throw const SocketException('offline'));
      final loader = loaderWith(api);
      final shown = (await loader.load(near)).churches;

      final list = await loader.refresh(near, shown);

      expect(list.failure, ApiFailure.noConnection);
      expect(list.churches, same(shown));
      expect(list.dataAsOf, DateTime(2026, 8, 1, 10, 0));
      expect((await cache.getChurch(1))!.name, 'Régi név');
    });

    test('a server error keeps what is shown and says so', () async {
      final api = _Api((_) async => http.Response('', 500));
      final loader = loaderWith(api);
      final shown = (await loader.load(near)).churches;

      final list = await loader.refresh(near, shown);

      expect(list.failure, ApiFailure.serverError);
      expect(list.churches, same(shown));
    });

    test('a failed refresh does not move the date of the data', () async {
      final loader = loaderWith(
          _Api((_) async => _json({'templomok': [], 'error': 0})));
      await loader.refresh(near, const []);

      final failing = ChurchListLoader(
        cache: cache,
        api: _Api((_) async => http.Response('', 500)).client,
        clock: () => _now.add(const Duration(days: 1)),
      );
      final list = await failing.refresh(near, const []);

      expect(list.dataAsOf, _now);
    });
  });

  group('refresh favorites', () {
    setUp(() async {
      await cache.importChurches([
        BootstrapImporter.churchFromLegacyRow(
            {'tid': 2, 'nev': 'Megszűnt templom', 'lat': 47.6, 'lng': 19.1}),
      ], const []);
    });

    test('reads the favorites from the cache, by name', () async {
      final list = await loaderWith(_Api((_) async => _json({})))
          .load(const FavoritesQuery([1, 2]));

      expect(list.churches.map((c) => c.name), ['Megszűnt templom', 'Régi név']);
    });

    test('asks the Church endpoint for every favorite, minimal', () async {
      final api = _Api((_) async =>
          _json({'templomok': [], 'hianyzo': [], 'error': 0}));

      await loaderWith(api).refresh(const FavoritesQuery([1, 2]), const []);

      expect(api.requests.single.url.path, '/api/v4/church');
      expect(jsonDecode(api.requests.single.body), {
        'ids': [1, 2],
        'response_length': 'minimal',
      });
    });

    test('a church the API no longer has leaves the cache and the favorites',
        () async {
      final gone = <int>[];
      final api = _Api((_) async => _json({
            'templomok': [_listed(1, 'Megmaradt')],
            'hianyzo': [2],
            'error': 0,
          }));
      final loader = ChurchListLoader(
        cache: cache,
        api: api.client,
        clock: () => _now,
        onChurchesGone: (ids) async => gone.addAll(ids),
      );

      final list =
          await loader.refresh(const FavoritesQuery([1, 2]), const []);

      expect(list.churches.map((c) => c.name), ['Megmaradt']);
      expect(await cache.getChurch(2), isNull);
      expect(gone, [2]);
    });
  });

  group('a church missing from a search or nearby answer', () {
    test('is not taken as removed', () async {
      final api = _Api((_) async => _json({'templomok': [], 'error': 0}));

      final list = await loaderWith(api).refresh(near, const []);

      expect(list.churches.map((c) => c.id), [1]);
      expect(await cache.getChurch(1), isNotNull);
    });
  });

  group('refresh search results', () {
    test('asks the Church endpoint for at most the first hundred found',
        () async {
      await cache.importChurches([
        for (var id = 100; id < 250; id++)
          BootstrapImporter.churchFromLegacyRow(
              {'tid': id, 'nev': 'Szent templom $id', 'lat': 47.5, 'lng': 19.0}),
      ], const []);
      final api = _Api((_) async =>
          _json({'templomok': [], 'hianyzo': [], 'error': 0}));
      final loader = loaderWith(api);
      const query = SearchQuery.byName('Szent');
      final shown = (await loader.load(query)).churches;

      await loader.refresh(query, shown);

      expect(shown, hasLength(150));
      expect(api.requests.single.url.path, '/api/v4/church');
      final ids = (jsonDecode(api.requests.single.body) as Map)['ids'] as List;
      expect(ids, shown.take(100).map((c) => c.id).toList());
    });

    test('with nothing found in the cache, asks Search and shows what it '
        'wrote', () async {
      final api = _Api((_) async => _json({
            'templomok': [_listed(4242, 'Új Szent Kereszt templom')],
            'error': 0,
          }));
      final loader = loaderWith(api);
      const query = SearchQuery.byName('Kereszt');
      final shown = (await loader.load(query)).churches;

      final list = await loader.refresh(query, shown);

      expect(shown, isEmpty);
      expect(api.requests.single.url.path, '/api/v4/search');
      expect(jsonDecode(api.requests.single.body), containsPair('q', 'Kereszt'));
      expect(list.churches.map((c) => c.name), ['Új Szent Kereszt templom']);
    });

    test('a city is searched in the cache by the city', () async {
      final list = await loaderWith(_Api((_) async => _json({})))
          .load(const SearchQuery.byCity('Budapest'));

      expect(list.churches, isEmpty,
          reason: 'the bootstrap row of this test has no city');
    });

    test('no connection keeps the found churches and says so', () async {
      final api = _Api((_) async => throw const SocketException('offline'));
      final loader = loaderWith(api);
      const query = SearchQuery.byName('Régi');
      final shown = (await loader.load(query)).churches;

      final list = await loader.refresh(query, shown);

      expect(list.churches.map((c) => c.name), ['Régi név']);
      expect(list.failure, ApiFailure.noConnection);
    });
  });
}
