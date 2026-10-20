import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:miserend/api/api_result.dart';
import 'package:miserend/api/api_status.dart';
import 'package:miserend/api/miserend_api_client.dart';
import 'package:miserend/database/cache/cache_database.dart';
import 'package:miserend/database/cache/cached_mass.dart';
import 'package:miserend/database/cache/church_details.dart';
import 'package:miserend/home/advanced_search/advanced_search_loader.dart';
import 'package:miserend/mass_kind.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A Sunday morning.
final DateTime _now = DateTime(2026, 9, 20, 10, 0);

final DateTime _monday = DateTime(2026, 9, 21);

/// Budakeszi, a few kilometres west of Budapest's churches below.
const LatLng _budakeszi = LatLng(47.51, 18.93);

ChurchDetails _church(
  int id,
  String name,
  String? city, {
  double? lat,
  double? lon,
  List<String> languages = const ['hu'],
  List<String> alternativeNames = const [],
}) => ChurchDetails(
  id: id,
  name: name,
  commonName: null,
  names: const [],
  alternativeNames: alternativeNames,
  country: 'Magyarország',
  diocese: null,
  county: null,
  city: city,
  street: null,
  gettingThere: null,
  parish: null,
  description: null,
  accessibility: null,
  email: null,
  links: const [],
  languages: languages,
  massScheduleNote: null,
  adorations: const [],
  hasConfession: null,
  communities: const [],
  lat: lat,
  lon: lon,
  photos: const [],
  updatedAt: null,
  localSyncedAt: null,
  isGreek: null,
);

CachedMass _cached(
  int churchId,
  DateTime time, {
  String? info,
  MassSource source = MassSource.bootstrap,
}) => CachedMass(
  id: null,
  apiMassId: null,
  churchId: churchId,
  time: time,
  info: info,
  source: source,
);

/// A seeded church as the `Church` endpoint answers with it, with no mass
/// today.
Map<String, Object?> _listed(ChurchDetails church) => {
  'id': church.id,
  'nev': church.name,
  'varos': church.city,
  'lat': church.lat,
  'lon': church.lon,
  'misek': [],
};

/// A `NearbyMasses` item of [churchId].
Map<String, Object?> _occurrence(
  int churchId,
  String start, {
  String title = 'Szentmise',
}) => {
  'id': churchId * 100,
  'start_date': start,
  'title': title,
  'distance_km': 0,
  'church': {'id': churchId, 'name': 'x', 'city': 'x', 'lat': 47.5, 'lon': 19},
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

  List<http.Request> to(String endpoint) =>
      requests.where((r) => r.url.path == '/api/v4/$endpoint').toList();
}

/// Answers `church` with the churches asked for, none missing, and
/// `nearbymasses` with [masses]' items of the church asked about.
_Api _answering({
  List<Map<String, Object?>> masses = const [],
  List<int> missing = const [],
}) => _Api((request) async {
  final body = jsonDecode(request.body) as Map<String, dynamic>;
  switch (request.url.path) {
    case '/api/v4/church':
      final ids = (body['ids'] as List).cast<int>();
      return _json({
        'templomok': [
          for (final id in ids)
            if (!missing.contains(id)) _listed(_seeded[id]!),
        ],
        'hianyzo': [
          for (final id in ids)
            if (missing.contains(id)) id,
        ],
        'error': 0,
      });
    case '/api/v4/nearbymasses':
      return _json({
        'misek': [
          for (final item in masses)
            if ((item['church'] as Map)['id'] == _churchAt(body)) item,
        ],
        'error': 0,
      });
  }
  throw StateError('unexpected ${request.url.path}');
});

/// Which church a `nearbymasses` request of the tests is about: each one
/// stands at a longitude of its own.
int? _churchAt(Map<String, dynamic> body) => _byLon[body['lon']];

final Map<double, int> _byLon = {};

final Map<int, ChurchDetails> _seeded = {};

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late CacheDatabase cache;

  Future<void> seed(List<ChurchDetails> churches, [List<CachedMass>? m]) async {
    for (final church in churches) {
      await cache.upsertChurch(church);
      _seeded[church.id] = church;
      if (church.lon != null) _byLon[church.lon!] = church.id;
    }
    await cache.importChurches(const [], m ?? const []);
  }

  setUp(() async {
    cache = await CacheDatabase.create(path: inMemoryDatabasePath);
    _byLon.clear();
    _seeded.clear();
    await seed([
      _church(
        1,
        'Mátyás templom',
        'Budapest I. kerület',
        lat: 47.502,
        lon: 19.034,
        languages: ['hu', 'va'],
      ),
      _church(
        2,
        'Szent István-bazilika',
        'Budapest V. kerület',
        lat: 47.5009,
        lon: 19.0539,
        languages: ['hu', 'en'],
      ),
      _church(3, 'Szent Mihály templom', 'Budakeszi', lat: 47.512, lon: 18.932),
      _church(
        4,
        'Dóm',
        'Szeged',
        lat: 46.25,
        lon: 20.15,
        alternativeNames: ['Fogadalmi templom'],
      ),
      _church(5, 'Szent Anna templom', 'Nemtudjuk'),
    ]);
    await cache.setBootstrappedAt(DateTime(2026, 9, 1, 10, 0));
  });

  tearDown(() async => cache.db.close());

  AdvancedSearchLoader loaderWith(_Api api, {List<int>? gone}) =>
      AdvancedSearchLoader(
        cache: cache,
        api: api.client,
        clock: () => _now,
        onChurchesGone: (ids) async => gone?.addAll(ids),
      );

  final noCall = _Api((_) async => throw StateError('no call expected'));

  Future<List<int>> idsFound(
    AdvancedSearchCriteria criteria, {
    _Api? api,
  }) async {
    final page = await loaderWith(api ?? noCall).loadPage(criteria, 0);
    return page.churches.map((c) => c.id).toList();
  }

  group('without a day', () {
    test(
      'a part of the name finds it, whatever the accents and case',
      () async {
        expect(await idsFound(const AdvancedSearchCriteria(name: 'MATYAS')), [
          1,
        ]);
      },
    );

    test('an alternative name finds the church', () async {
      expect(await idsFound(const AdvancedSearchCriteria(name: 'fogadalmi')), [
        4,
      ]);
    });

    test('a part of a city finds every city containing it, ordered by city '
        'and then by name', () async {
      expect(await idsFound(const AdvancedSearchCriteria(city: 'buda')), [
        3,
        1,
        2,
      ]);
    });

    test('Budapest finds the churches of every district', () async {
      expect(await idsFound(const AdvancedSearchCriteria(city: 'Budapest')), [
        1,
        2,
      ]);
    });

    test('a church has to meet every condition given', () async {
      expect(
        await idsFound(
          const AdvancedSearchCriteria(name: 'szent', city: 'budapest'),
        ),
        [2],
      );
    });

    test('the language keeps the churches that serve in it', () async {
      expect(
        await idsFound(
          const AdvancedSearchCriteria(city: 'buda', language: 'va'),
        ),
        [1],
      );
    });

    test('with no city, a known position orders by straight-line distance, '
        'churches without a position last', () async {
      expect(
        await idsFound(
          const AdvancedSearchCriteria(name: 'szent', position: _budakeszi),
        ),
        [3, 2, 5],
      );
    });

    test('with neither a city nor a position, orders by name', () async {
      expect(await idsFound(const AdvancedSearchCriteria(name: 'templom')), [
        4,
        1,
        5,
        3,
      ]);
    });

    test('a city orders by city even when the position is known', () async {
      expect(
        await idsFound(
          const AdvancedSearchCriteria(city: 'buda', position: _budakeszi),
        ),
        [3, 1, 2],
      );
    });

    test('each church shows today\'s masses, without asking the API', () async {
      await cache.importChurches(const [], [
        _cached(1, DateTime(2026, 9, 20, 8, 0)),
        _cached(1, DateTime(2026, 9, 21, 8, 0)),
      ]);

      final page = await loaderWith(
        noCall,
      ).loadPage(const AdvancedSearchCriteria(name: 'matyas'), 0);

      expect(page.churches.single.masses.map((m) => m.time), [
        DateTime(2026, 9, 20, 8, 0),
      ]);
      expect(page.failure, isNull);
      expect(noCall.requests, isEmpty);
    });

    test(
      'each church shows today\'s occasions of every kind, as other lists do',
      () async {
        await cache.importChurches(const [], [
          _cached(1, DateTime(2026, 9, 20, 8, 0)),
          _cached(
            1,
            DateTime(2026, 9, 20, 9, 0),
            info: 'Római katolikus Gyóntatás',
            source: MassSource.dailyList,
          ),
        ]);

        final page = await loaderWith(
          noCall,
        ).loadPage(const AdvancedSearchCriteria(name: 'matyas'), 0);

        expect(page.churches.single.masses.map((m) => m.time), [
          DateTime(2026, 9, 20, 8, 0),
          DateTime(2026, 9, 20, 9, 0),
        ]);
      },
    );

    test('the categories narrow nothing', () async {
      await cache.importChurches(const [], [
        _cached(1, DateTime(2026, 9, 20, 8, 0)),
      ]);

      final page = await loaderWith(noCall).loadPage(
        const AdvancedSearchCriteria(
          name: 'matyas',
          categories: {OccasionCategory.confession},
        ),
        0,
      );

      expect(page.churches.single.masses.map((m) => m.time), [
        DateTime(2026, 9, 20, 8, 0),
      ]);
    });
  });

  group('pages', () {
    setUp(() async {
      await seed([
        for (var i = 1; i <= 25; i++)
          _church(
            100 + i,
            'Templom ${i.toString().padLeft(2, '0')}',
            'Tesztfalu',
          ),
      ]);
    });

    const inTheVillage = AdvancedSearchCriteria(city: 'Tesztfalu');

    test('without a day, every candidate is counted at once', () async {
      final loader = loaderWith(noCall);

      final first = await loader.loadPage(inTheVillage, 0);
      final second = await loader.loadPage(inTheVillage, 1);

      expect(first.churches.map((c) => c.name), [
        for (var i = 1; i <= 20; i++) 'Templom ${i.toString().padLeft(2, '0')}',
      ]);
      expect(first.hasMore, isTrue);
      expect((first.found, first.foundIsFinal), (25, true));
      expect(second.churches.map((c) => c.name), [
        for (var i = 21; i <= 25; i++) 'Templom $i',
      ]);
      expect(second.hasMore, isFalse);
    });

    test('with a day, only the candidates of the page asked for are looked '
        'at, and the count grows page by page', () async {
      final api = _answering();
      final loader = loaderWith(api);
      final monday = AdvancedSearchCriteria(city: 'Tesztfalu', day: _monday);
      await cache.importChurches(const [], [
        for (var i = 1; i <= 25; i++)
          _cached(100 + i, DateTime(2026, 9, 21, 9, 0)),
      ]);

      final first = await loader.loadPage(monday, 0);
      final asked = (jsonDecode(api.to('church').single.body) as Map)['ids'];
      final second = await loader.loadPage(monday, 1);

      expect(asked, [for (var i = 1; i <= 20; i++) 100 + i]);
      // Churches without a position are not asked about; their cached
      // masses decide.
      expect(api.to('nearbymasses'), isEmpty);
      expect(
        (first.found, first.foundIsFinal, first.hasMore),
        (20, false, true),
      );
      expect(
        (second.found, second.foundIsFinal, second.hasMore),
        (25, true, false),
      );
    });
  });

  group('with a day', () {
    test('a church holding a mass that day is found, with that day\'s masses '
        'as the reason', () async {
      final api = _answering(
        masses: [
          _occurrence(1, '2026-09-21T08:00:00+02:00'),
          _occurrence(1, '2026-09-21T18:00:00+02:00'),
          _occurrence(1, '2026-09-22T08:00:00+02:00'),
        ],
      );

      final page = await loaderWith(
        api,
      ).loadPage(AdvancedSearchCriteria(city: 'Budapest', day: _monday), 0);

      expect(page.churches.map((c) => c.id), [1]);
      expect(page.churches.single.masses.map((m) => m.time), [
        DateTime(2026, 9, 21, 8, 0),
        DateTime(2026, 9, 21, 18, 0),
      ]);
      expect(page.failure, isNull);
    });

    test('asks the API for that day of the page\'s churches only', () async {
      final api = _answering();

      await loaderWith(
        api,
      ).loadPage(AdvancedSearchCriteria(city: 'Budapest', day: _monday), 0);

      expect((jsonDecode(api.to('church').single.body) as Map)['ids'], [1, 2]);
      expect(
        [
          for (final request in api.to('nearbymasses'))
            (jsonDecode(request.body) as Map)['from'],
        ],
        ['2026-09-21', '2026-09-21'],
      );
    });

    test('the answer replaces the day\'s cached masses', () async {
      await cache.importChurches(const [], [
        _cached(1, DateTime(2026, 9, 21, 7, 0)),
      ]);
      final api = _answering(
        masses: [_occurrence(1, '2026-09-21T19:00:00+02:00')],
      );

      final page = await loaderWith(
        api,
      ).loadPage(AdvancedSearchCriteria(name: 'matyas', day: _monday), 0);

      expect(page.churches.single.masses.map((m) => m.time), [
        DateTime(2026, 9, 21, 19, 0),
      ]);
      expect((await cache.getMassesForChurch(1)).map((m) => m.time), [
        DateTime(2026, 9, 21, 19, 0),
      ]);
    });

    test('the time window keeps both of its ends', () async {
      final api = _answering(
        masses: [
          _occurrence(1, '2026-09-21T08:59:00+02:00'),
          _occurrence(1, '2026-09-21T09:00:00+02:00'),
          _occurrence(2, '2026-09-21T12:00:00+02:00'),
          _occurrence(2, '2026-09-21T12:01:00+02:00'),
        ],
      );

      final page = await loaderWith(api).loadPage(
        AdvancedSearchCriteria(
          city: 'Budapest',
          day: _monday,
          from: const TimeOfDay(hour: 9, minute: 0),
          until: const TimeOfDay(hour: 12, minute: 0),
        ),
        0,
      );

      expect(
        {
          for (final church in page.churches)
            church.id: church.masses.map((m) => m.time).toList(),
        },
        {
          1: [DateTime(2026, 9, 21, 9, 0)],
          2: [DateTime(2026, 9, 21, 12, 0)],
        },
      );
    });

    test('an event other than a mass finds nothing', () async {
      final api = _answering(
        masses: [
          _occurrence(1, '2026-09-21T08:00:00+02:00', title: 'Gyóntatás'),
          _occurrence(2, '2026-09-21T17:00:00+02:00', title: 'Vecsernye'),
        ],
      );

      expect(
        await idsFound(
          AdvancedSearchCriteria(city: 'Budapest', day: _monday),
          api: api,
        ),
        isEmpty,
      );
    });

    test('a search for adoration finds the churches holding one in the '
        'window, with its times and not the masses\'', () async {
      final api = _answering(
        masses: [
          _occurrence(1, '2026-09-21T09:00:00+02:00'),
          _occurrence(1, '2026-09-21T10:00:00+02:00', title: 'Szentségimádás'),
          _occurrence(1, '2026-09-21T13:00:00+02:00', title: 'Szentségimádás'),
          _occurrence(2, '2026-09-21T10:00:00+02:00'),
          _occurrence(2, '2026-09-21T11:00:00+02:00', title: 'Gyóntatás'),
        ],
      );

      final page = await loaderWith(api).loadPage(
        AdvancedSearchCriteria(
          city: 'Budapest',
          day: _monday,
          from: const TimeOfDay(hour: 9, minute: 0),
          until: const TimeOfDay(hour: 12, minute: 0),
          categories: const {OccasionCategory.adoration},
        ),
        0,
      );

      expect(page.churches.map((c) => c.id), [1]);
      expect(page.churches.single.masses.map((m) => m.time), [
        DateTime(2026, 9, 21, 10, 0),
      ]);
    });

    test('a search for every category counts every occasion, one of an '
        'unknown kind too', () async {
      final api = _answering(
        masses: [
          _occurrence(1, '2026-09-21T08:00:00+02:00', title: 'Ismeretlen'),
          _occurrence(2, '2026-09-21T17:00:00+02:00', title: 'Gyóntatás'),
        ],
      );

      expect(
        await idsFound(
          AdvancedSearchCriteria(
            city: 'Budapest',
            day: _monday,
            categories: OccasionCategory.values.toSet(),
          ),
          api: api,
        ),
        [1, 2],
      );
    });

    test('a church the API no longer has is not found, and leaves the cache '
        'and the favorites', () async {
      final gone = <int>[];
      final api = _answering(
        masses: [
          _occurrence(1, '2026-09-21T08:00:00+02:00'),
          _occurrence(2, '2026-09-21T08:00:00+02:00'),
        ],
        missing: [2],
      );

      final page = await loaderWith(
        api,
        gone: gone,
      ).loadPage(AdvancedSearchCriteria(city: 'Budapest', day: _monday), 0);

      expect(page.churches.map((c) => c.id), [1]);
      expect(gone, [2]);
      expect(await cache.getChurch(2), isNull);
    });
  });

  group('with a day, when the API gives no answer', () {
    final waits = <Duration>[];
    setUp(waits.clear);

    AdvancedSearchLoader retryingWith(_Api api) => AdvancedSearchLoader(
      cache: cache,
      api: api.client,
      clock: () => _now,
      wait: (duration) async => waits.add(duration),
    );

    /// Fails the first [failures] calls with [failure], then answers as
    /// [answering] does.
    _Api failingFirst(
      int failures,
      _Api answering, {
      ApiFailure failure = ApiFailure.noConnection,
    }) {
      var failed = 0;
      return _Api((request) async {
        if (failed < failures) {
          failed++;
          if (failure == ApiFailure.noConnection) {
            throw const SocketException('offline');
          }
          return http.Response('', 500);
        }
        return answering.answer(request);
      });
    }

    test(
      'tries again after 2 seconds, and carries on as if nothing happened',
      () async {
        final api = failingFirst(
          1,
          _answering(masses: [_occurrence(1, '2026-09-21T08:00:00+02:00')]),
        );

        final page = await retryingWith(
          api,
        ).loadPage(AdvancedSearchCriteria(city: 'Budapest', day: _monday), 0);

        expect(page.churches.map((c) => c.id), [1]);
        expect(page.failure, isNull);
        expect(waits, [const Duration(seconds: 2)]);
      },
    );

    test('a server error on one church\'s masses is tried again too', () async {
      final answering = _answering(
        masses: [
          _occurrence(1, '2026-09-21T08:00:00+02:00'),
          _occurrence(2, '2026-09-21T10:00:00+02:00'),
        ],
      );
      var failed = false;
      final api = _Api((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (!failed &&
            request.url.path == '/api/v4/nearbymasses' &&
            _churchAt(body) == 2) {
          failed = true;
          return http.Response('', 500);
        }
        return answering.answer(request);
      });

      final page = await retryingWith(
        api,
      ).loadPage(AdvancedSearchCriteria(city: 'Budapest', day: _monday), 0);

      expect(page.churches.map((c) => c.id), [1, 2]);
      expect(page.failure, isNull);
    });

    test('gives up after three retries, 2, 4 and 8 seconds apart, finding '
        'nothing from the cache', () async {
      await cache.importChurches(const [], [
        _cached(1, DateTime(2026, 9, 21, 8, 0)),
      ]);
      final api = _Api((_) async => throw const SocketException('offline'));

      final page = await retryingWith(
        api,
      ).loadPage(AdvancedSearchCriteria(city: 'Budapest', day: _monday), 0);

      expect(page.churches, isEmpty);
      expect(page.failure, ApiFailure.noConnection);
      expect(page.found, 0);
      expect(page.foundIsFinal, isFalse);
      expect(waits, const [
        Duration(seconds: 2),
        Duration(seconds: 4),
        Duration(seconds: 8),
      ]);
      // Four tries of the page's `Church` call, and nothing past it.
      expect(api.to('church'), hasLength(4));
      expect(api.to('nearbymasses'), isEmpty);
    });

    test('says which failure it gave up on', () async {
      final page = await retryingWith(
        failingFirst(4, _answering(), failure: ApiFailure.serverError),
      ).loadPage(AdvancedSearchCriteria(city: 'Budapest', day: _monday), 0);

      expect(page.failure, ApiFailure.serverError);
    });

    test('given up on a later page, the count keeps what was found and stays '
        'open', () async {
      final churches = [
        for (var id = 10; id < 10 + AdvancedSearchLoader.pageSize + 1; id++)
          _church(id, 'Templom $id', 'Pécs', lat: 46, lon: 18 + id / 1000),
      ];
      await seed(churches);
      final answering = _answering(
        masses: [
          for (final church in churches)
            _occurrence(church.id, '2026-09-21T08:00:00+02:00'),
        ],
      );
      var offline = false;
      final api = _Api(
        (request) async =>
            offline
                ? throw const SocketException('offline')
                : answering.answer(request),
      );
      final loader = retryingWith(api);
      final criteria = AdvancedSearchCriteria(city: 'Pécs', day: _monday);

      final first = await loader.loadPage(criteria, 0);
      offline = true;
      final second = await loader.loadPage(criteria, 1);

      expect(first.churches, hasLength(AdvancedSearchLoader.pageSize));
      expect(second.churches, isEmpty);
      expect(second.failure, ApiFailure.noConnection);
      expect(second.found, AdvancedSearchLoader.pageSize);
      expect(second.foundIsFinal, isFalse);
    });
  });

  group('the connection', () {
    test(
      'is down while the last call got no answer, and up after one did',
      () async {
        final status = ApiStatus();
        var offline = true;
        final api = _Api(
          (request) async =>
              offline
                  ? throw const SocketException('offline')
                  : _answering().answer(request),
        );
        final loader = AdvancedSearchLoader(
          cache: cache,
          api: MiserendApiClient(
            client: MockClient((request) async {
              api.requests.add(request);
              return api.answer(request);
            }),
            status: status,
          ),
          clock: () => _now,
        );

        await loader.checkConnection();
        expect(loader.lastFailure.value, ApiFailure.noConnection);

        offline = false;
        await loader.checkConnection();
        expect(loader.lastFailure.value, isNull);
        // One small call each time.
        expect(api.requests, hasLength(2));
        expect(api.to('church'), hasLength(2));
      },
    );
  });

  test('the languages are those the cached churches serve in, Hungarian '
      'left out', () async {
    expect(await loaderWith(noCall).languages(), ['en', 'va']);
  });
}
