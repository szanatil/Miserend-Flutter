import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miserend/api/miserend_api_client.dart';
import 'package:miserend/database/cache/bootstrap_importer.dart';
import 'package:miserend/database/cache/cache_database.dart';
import 'package:miserend/database/cache/cached_mass.dart';
import 'package:miserend/favorites_prefetch.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database/fake_favorites_service.dart';

http.Response _json(Object body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), 200);

/// Answers the Church call for [ids] (reporting [missing]) and every
/// schedule call with one mass; [failing] makes every call look offline.
class _Api {
  _Api({this.missing = const [], this.failing = false});

  final List<int> missing;
  bool failing;
  final List<String> paths = [];

  MiserendApiClient get client => MiserendApiClient(
    client: MockClient((request) async {
      paths.add(request.url.path);
      if (failing) throw const SocketException('offline');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (request.url.path.endsWith('/church')) {
        final ids = (body['ids'] as List).cast<int>();
        return _json({
          'templomok': [
            for (final id in ids)
              if (!missing.contains(id))
                {'id': id, 'nev': 'Templom $id', 'lat': 47.5, 'lon': 19.0},
          ],
          'hianyzo': missing,
          'error': 0,
        });
      }
      return _json({
        'error': 0,
        'misek': [
          {
            'id': 1,
            'start_date': '2026-09-20T10:00:00+02:00',
            'title': 'Szentmise',
            // The schedule call is made per church, by its position; the
            // fake does not know which, so it answers for all of them.
            'church': {'id': -1},
          },
        ],
      });
    }),
  );
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late CacheDatabase cache;
  var now = DateTime(2026, 9, 15, 8, 0);

  setUp(() async {
    now = DateTime(2026, 9, 15, 8, 0);
    cache = await CacheDatabase.create(path: inMemoryDatabasePath);
    await cache.importChurches([
      for (final id in [1, 2, 3])
        BootstrapImporter.churchFromLegacyRow({
          'tid': id,
          'nev': 'Templom $id',
          'lat': 47.5,
          'lng': 19.0,
        }),
    ], const []);
  });

  tearDown(() async => cache.db.close());

  FavoritesPrefetch prefetchWith(_Api api, {List<int>? gone}) =>
      FavoritesPrefetch(
        cache: cache,
        api: api.client,
        clock: () => now,
        onChurchesGone: (ids) async => gone?.addAll(ids),
      );

  int churchCalls(_Api api) =>
      api.paths.where((p) => p == '/api/v4/church').length;
  int scheduleCalls(_Api api) =>
      api.paths.where((p) => p == '/api/v4/nearbymasses').length;

  test(
    'asks once for every favorite, then each favorite\'s schedule',
    () async {
      final api = _Api();

      await prefetchWith(api).runIfDue([1, 2, 3]);

      expect(churchCalls(api), 1);
      expect(scheduleCalls(api), 3);
    },
  );

  test('stores the schedule it gets as the details page would', () async {
    final api = MiserendApiClient(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/church')) {
          return _json({
            'templomok': [
              {'id': 1, 'nev': 'Templom 1', 'lat': 47.5, 'lon': 19.0},
            ],
            'hianyzo': [],
            'error': 0,
          });
        }
        return _json({
          'error': 0,
          'misek': [
            {
              'id': 7,
              'start_date': '2026-09-20T10:00:00+02:00',
              'title': 'Szentmise',
              'church': {'id': 1},
            },
          ],
        });
      }),
    );

    await FavoritesPrefetch(
      cache: cache,
      api: api,
      clock: () => now,
    ).runIfDue([1]);

    final masses = await cache.getMassesForChurch(1);
    expect(masses.single.time, DateTime(2026, 9, 20, 10, 0));
    expect(masses.single.source, MassSource.nearbyMasses);
  });

  test('does not run again within 24 hours, and does after', () async {
    final api = _Api();
    await prefetchWith(api).runIfDue([1]);

    now = now.add(const Duration(hours: 23, minutes: 59));
    await prefetchWith(api).runIfDue([1]);
    expect(churchCalls(api), 1);

    now = now.add(const Duration(minutes: 1));
    await prefetchWith(api).runIfDue([1]);
    expect(churchCalls(api), 2);
  });

  test('a failure is silent and does not count as a run', () async {
    final api = _Api(failing: true);

    await expectLater(prefetchWith(api).runIfDue([1, 2]), completes);
    expect(scheduleCalls(api), 0);

    api.failing = false;
    now = now.add(const Duration(minutes: 5));
    await prefetchWith(api).runIfDue([1, 2]);
    expect(churchCalls(api), 2);
    expect(scheduleCalls(api), 2);
  });

  test(
    'a favorite removed from miserend.hu is let go, with no schedule call',
    () async {
      final api = _Api(missing: [2]);
      final gone = <int>[];

      await prefetchWith(api, gone: gone).runIfDue([1, 2]);

      expect(gone, [2]);
      expect(await cache.getChurch(2), isNull);
      expect(scheduleCalls(api), 1);
    },
  );

  test('with no favorites, asks nothing', () async {
    final api = _Api();

    await prefetchWith(api).runIfDue(const []);

    expect(api.paths, isEmpty);
  });
  group('startWhenLoaded', () {
    /// Lets the run get as far as its first API call.
    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 50));

    test('waits for the favorites to be read, starts once, and nothing '
        'waits on its answer', () async {
      final api = _HeldApi();
      final favorites = FakeFavoritesService(const [1, 2], loaded: false);

      FavoritesPrefetch(
        cache: cache,
        api: api.client,
        clock: () => now,
      ).startWhenLoaded(favorites);
      await settle();
      expect(api.paths, isEmpty);

      favorites.finishLoading();
      await settle();
      // Back here with the Church call still unanswered.
      expect(api.paths, ['/api/v4/church']);

      favorites.finishLoading();
      await settle();
      expect(api.paths, hasLength(1));
      api.release();
    });

    test('favorites already read start the run at once', () async {
      final api = _HeldApi();

      FavoritesPrefetch(
        cache: cache,
        api: api.client,
        clock: () => now,
      ).startWhenLoaded(FakeFavoritesService(const [1]));
      await settle();

      expect(api.paths, ['/api/v4/church']);
      api.release();
    });
  });
}

/// Holds every call until [release], then answers as if offline.
class _HeldApi {
  final Completer<void> _answer = Completer();
  final List<String> paths = [];

  void release() => _answer.complete();

  MiserendApiClient get client => MiserendApiClient(
    client: MockClient((request) async {
      paths.add(request.url.path);
      await _answer.future;
      throw const SocketException('offline');
    }),
  );
}
