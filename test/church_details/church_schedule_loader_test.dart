import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miserend/api/miserend_api_client.dart';
import 'package:miserend/church_details/church_schedule_loader.dart';
import 'package:miserend/database/cache/cache_database.dart';
import 'package:miserend/database/cache/cached_mass.dart';
import 'package:miserend/database/church.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final DateTime _today = DateTime(2026, 9, 10);

final Church _church = Church(
  id: 38,
  name: 'Belvárosi Nagyboldogasszony-templom',
  commonName: 'Főplébániatemplom',
  isGreek: false,
  lat: 47.492233,
  lon: 19.0522943,
  address: null,
  city: 'Budapest',
  country: 'Magyarország',
  county: 'Budapest',
  street: 'Március 15. tér',
  gettingThere: null,
  imageUrl: null,
);

CachedMass _mass(DateTime time, String info) => CachedMass(
      id: null,
      apiMassId: null,
      churchId: 38,
      time: time,
      info: info,
    );

String _nearbyMassesAt(List<DateTime> times) {
  String two(int n) => n.toString().padLeft(2, '0');
  return jsonEncode({
    'error': 0,
    'sum': times.length,
    'misek': [
      for (final time in times)
        {
          'id': 129807,
          'start_date': '${time.year}-${two(time.month)}-${two(time.day)}'
              'T${two(time.hour)}:${two(time.minute)}:00+02:00',
          'title': 'Szentmise',
          'church': {'id': 38},
        },
    ],
  });
}

/// Answers the church call from the recorded response and the masses call from
/// [massTimes]; [failing] makes every call look like there is no network.
MiserendApiClient _api({List<DateTime> massTimes = const [], bool failing = false}) {
  return MiserendApiClient(client: MockClient((request) async {
    if (failing) {
      throw const SocketException('offline');
    }
    if (request.url.path.endsWith('nearbymasses')) {
      return http.Response.bytes(utf8.encode(_nearbyMassesAt(massTimes)), 200);
    }
    return http.Response.bytes(
        File('test/fixtures/church_38.json').readAsBytesSync(), 200);
  }));
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
    test('buckets the cached masses by day', () async {
      await cache.replaceMassesForChurch(38, [
        _mass(DateTime(2026, 9, 10, 17, 0), 'Ma'),
        _mass(DateTime(2026, 9, 10, 18, 30), 'Ma este'),
        _mass(DateTime(2026, 9, 13, 10, 0), 'Vasárnap'),
      ]);

      final days = await ChurchScheduleLoader(cache: cache, api: _api())
          .loadCached(38, _today);

      expect(days, hasLength(ChurchScheduleLoader.scheduleDays));
      expect(days[0].map((m) => m.info), ['Ma', 'Ma este']);
      expect(days[1], isEmpty);
      expect(days[3].map((m) => m.info), ['Vasárnap']);
    });

    test('leaves out what falls outside the window', () async {
      await cache.replaceMassesForChurch(38, [
        _mass(DateTime(2026, 9, 9, 17, 0), 'Tegnap'),
        _mass(DateTime(2026, 10, 30, 17, 0), 'Jövő hónap'),
      ]);

      final days = await ChurchScheduleLoader(cache: cache, api: _api())
          .loadCached(38, _today);

      expect(days.expand((day) => day), isEmpty);
    });

    test('is all empty for a church with nothing cached', () async {
      final days = await ChurchScheduleLoader(cache: cache, api: _api())
          .loadCached(38, _today);

      expect(days, hasLength(ChurchScheduleLoader.scheduleDays));
      expect(days.expand((day) => day), isEmpty);
    });
  });

  group('refresh', () {
    test('replaces the cached masses with the API answer', () async {
      await cache.replaceMassesForChurch(38, [
        _mass(DateTime(2026, 9, 10, 9, 0), 'Bootstrap mise'),
      ]);

      final loader = ChurchScheduleLoader(
        cache: cache,
        api: _api(massTimes: [DateTime(2026, 9, 10, 18, 30)]),
      );
      final days = await loader.refresh(_church, _today);

      expect(days[0].map((m) => m.time), [DateTime(2026, 9, 10, 18, 30)]);
      final stored = await cache.getMassesForChurch(38);
      expect(stored.single.apiMassId, 129807);
    });

    test('writes the church response into the cache', () async {
      final loader = ChurchScheduleLoader(
        cache: cache,
        api: _api(massTimes: [DateTime(2026, 9, 10, 18, 30)]),
      );

      await loader.refresh(_church, _today);

      final stored = (await cache.getChurch(38))!;
      expect(stored.email, 'iroda.belvarosiplebania@gmail.com');
      expect(stored.photos, hasLength(7));
      expect(stored.adorations, hasLength(5));
      expect(stored.localSyncedAt, isNotNull);
    });

    test('keeps the cached masses when the API cannot be reached', () async {
      await cache.replaceMassesForChurch(38, [
        _mass(DateTime(2026, 9, 10, 9, 0), 'Bootstrap mise'),
      ]);

      final loader =
          ChurchScheduleLoader(cache: cache, api: _api(failing: true));
      final days = await loader.refresh(_church, _today);

      expect(days[0].map((m) => m.info), ['Bootstrap mise']);
    });

    test('keeps the cached masses when the API answers with none', () async {
      await cache.replaceMassesForChurch(38, [
        _mass(DateTime(2026, 9, 10, 9, 0), 'Bootstrap mise'),
      ]);

      final loader = ChurchScheduleLoader(cache: cache, api: _api());
      final days = await loader.refresh(_church, _today);

      // An empty answer is indistinguishable from a failed one.
      expect(days[0].map((m) => m.info), ['Bootstrap mise']);
    });

    test('skips the masses call for a church with no coordinates', () async {
      var askedForMasses = false;
      final api = MiserendApiClient(client: MockClient((request) async {
        if (request.url.path.endsWith('nearbymasses')) {
          askedForMasses = true;
        }
        return http.Response.bytes(
            File('test/fixtures/church_38.json').readAsBytesSync(), 200);
      }));

      final noCoordinates = Church(
        id: 38,
        name: 'Templom',
        commonName: null,
        isGreek: false,
        lat: null,
        lon: null,
        address: null,
        city: null,
        country: null,
        county: null,
        street: null,
        gettingThere: null,
        imageUrl: null,
      );

      await ChurchScheduleLoader(cache: cache, api: api)
          .refresh(noCoordinates, _today);

      expect(askedForMasses, isFalse);
      expect(await cache.getChurch(38), isNotNull);
    });
  });
}
