import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miserend/api/miserend_api_client.dart';
import 'package:miserend/api/nearby_masses_item.dart';
import 'package:miserend/database/cache/cache_database.dart';
import 'package:miserend/database/cache/church_details.dart';
import 'package:miserend/home/masses/nearest_masses.dart';
import 'package:miserend/home/masses/nearest_masses_loader.dart';
import 'package:miserend/location_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fake_location_provider.dart';

ChurchDetails _church(int id, {required List<String> photos}) => ChurchDetails(
  id: id,
  name: 'Szent István-bazilika',
  commonName: null,
  names: const [],
  alternativeNames: const [],
  country: null,
  diocese: null,
  county: null,
  city: 'Budapest V. kerület',
  street: null,
  gettingThere: null,
  parish: null,
  description: null,
  accessibility: null,
  email: null,
  links: const [],
  languages: const [],
  massScheduleNote: null,
  adorations: const [],
  hasConfession: null,
  communities: const [],
  lat: 47.5007789,
  lon: 19.0539695,
  photos: photos,
  updatedAt: null,
  localSyncedAt: null,
  isGreek: null,
);

/// Central Budapest, where the fixtures were recorded.
final Position _budapest = Position(
  latitude: 47.4979,
  longitude: 19.0402,
  timestamp: DateTime(2026, 9, 17, 6, 0),
  accuracy: 10,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

/// The morning the fixtures were recorded for.
final DateTime _morning = DateTime(2026, 9, 17, 6, 0);

String _fixture(String name) => File('test/fixtures/$name').readAsStringSync();

http.Response _json(String body) => http.Response.bytes(utf8.encode(body), 200);

/// Answers `NearbyMasses` and `Church` from the recorded central Budapest
/// fixtures, or [church] in place of the latter, and records which endpoints
/// were asked and with which ids.
class _Api {
  _Api({this.church});

  final Future<http.Response> Function()? church;
  final List<String> endpoints = [];
  final List<List<Object?>> churchIds = [];

  MiserendApiClient get client => MiserendApiClient(
    client: MockClient((request) async {
      final endpoint = request.url.pathSegments.last;
      endpoints.add(endpoint);
      if (endpoint == 'nearbymasses') {
        return _json(_fixture('nearbymasses_budapest_2026-09-17.json'));
      }
      churchIds.add((jsonDecode(request.body) as Map)['ids'] as List);
      return church?.call() ??
          _json(_fixture('church_ids_budapest_2026-09-17.json'));
    }),
  );
}

/// A `Church` answer holding one church, [churchId], with today's [misek].
http.Response _churchWith(int churchId, Map<String, String> misek) => _json(
  jsonEncode({
    'templomok': [
      {
        'id': churchId,
        'nev': 'Templom $churchId',
        'misek': [
          for (final MapEntry(key: info, value: time) in misek.entries)
            {'idopont': time, 'informacio': info},
        ],
      },
    ],
    'hianyzo': [],
    'error': 0,
  }),
);

NearbyMassesItem _item(int churchId, DateTime start, String title) =>
    NearbyMassesItem(
      churchId: churchId,
      churchName: 'Templom $churchId',
      city: 'Budapest',
      lat: null,
      lon: null,
      distanceKm: 1,
      start: start,
      title: title,
    );

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late CacheDatabase cache;

  setUp(() async {
    cache = await CacheDatabase.create(path: inMemoryDatabasePath);
  });

  tearDown(() async => cache.db.close());

  group('thumbnailUrl', () {
    test('is the first cached photo of the church with that id', () async {
      await cache.upsertChurch(
        _church(
          37,
          photos: const [
            'https://miserend.hu/kepek/templomok/37/elso.jpg',
            'https://miserend.hu/kepek/templomok/37/masodik.jpg',
          ],
        ),
      );
      await cache.upsertChurch(
        _church(
          38,
          photos: const ['https://miserend.hu/kepek/templomok/38/elso.jpg'],
        ),
      );
      final loader = NearestMassesLoader(cache: cache);

      expect(
        await loader.thumbnailUrl(37),
        'https://miserend.hu/kepek/templomok/37/elso.jpg',
      );
    });

    test('is null for a church with no photo', () async {
      await cache.upsertChurch(_church(37, photos: const []));
      final loader = NearestMassesLoader(cache: cache);

      expect(await loader.thumbnailUrl(37), isNull);
    });

    test('is null for a church the cache does not hold', () async {
      final loader = NearestMassesLoader(cache: cache);

      expect(await loader.thumbnailUrl(999), isNull);
    });
  });

  group('mass details', () {
    late _Api api;
    late NearestMassesLoader loader;

    NearestMassesLoader loaderFor(_Api api) => NearestMassesLoader(
      api: api.client,
      cache: cache,
      location: FakeLocationProvider([PositionFound(_budapest)]),
    );

    setUp(() {
      api = _Api();
      loader = loaderFor(api);
    });

    Future<List<NearbyMassesItem>> nearestMasses() async =>
        selectNearestMasses(await loader.fetch(_morning), _morning);

    String? detailAt(
      MassDetails details,
      List<NearbyMassesItem> masses,
      int churchId,
      int hour,
      int minute,
    ) => details.of(
      masses.singleWhere(
        (m) =>
            m.churchId == churchId &&
            m.start == DateTime(2026, 9, 17, hour, minute),
      ),
    );

    test('the list is fetched without asking for the churches', () async {
      await nearestMasses();

      expect(api.endpoints, ['nearbymasses']);
    });

    test('are asked for in one call for the churches on the list', () async {
      final masses = await nearestMasses();

      await loader.fetchMassDetails(masses, _morning);

      expect(api.endpoints, ['nearbymasses', 'church']);
      expect(
        api.churchIds.single.toSet(),
        masses.map((m) => m.churchId).toSet(),
      );
    });

    test('go with the mass starting at the same time', () async {
      final masses = await nearestMasses();

      final details = await loader.fetchMassDetails(masses, _morning);

      expect(detailAt(details, masses, 37, 7, 0), 'Csendes (Mária-kápolnában)');
      expect(detailAt(details, masses, 36, 9, 0), 'latin nyelven');
      expect(detailAt(details, masses, 36, 10, 0), isNull);
    });

    test('two masses of one church each get their own', () async {
      final masses = await nearestMasses();

      final details = await loader.fetchMassDetails(masses, _morning);

      expect(detailAt(details, masses, 1515, 7, 0), 'Csendes');
      expect(detailAt(details, masses, 1515, 18, 0), isNull);
    });

    test('a failed call leaves every mass without one, quietly', () async {
      api = _Api(church: () async => http.Response('', 500));
      loader = loaderFor(api);
      final masses = await nearestMasses();

      final details = await loader.fetchMassDetails(masses, _morning);

      for (final mass in masses) {
        expect(details.of(mass), isNull);
      }
    });

    test('the churches answered are written through to the cache', () async {
      final masses = await nearestMasses();

      await loader.fetchMassDetails(masses, _morning);

      expect((await cache.getChurch(37))?.name, isNotNull);
    });

    group('with several descriptions at the start', () {
      final at18 = DateTime(2026, 9, 17, 18, 0);

      test('the one whose kind is the title goes on the card', () async {
        loader = loaderFor(
          _Api(
            church:
                () async => _churchWith(7, {
                  'Görögkatolikus Szent Liturgia, Csendes':
                      '2026-09-17 18:00:00',
                  'Római katolikus Szentmise latin nyelven':
                      '2026-09-17 18:00:00',
                  'Római katolikus Gyóntatás angol nyelven':
                      '2026-09-17 18:00:00',
                }),
          ),
        );
        final masses = [
          _item(7, at18, 'Szentmise'),
          _item(7, at18, 'Szent Liturgia'),
        ];

        final details = await loader.fetchMassDetails(masses, _morning);

        expect(details.of(masses[0]), 'latin nyelven');
        expect(details.of(masses[1]), 'Csendes');
      });

      test('none goes on the card when the kind does not decide', () async {
        loader = loaderFor(
          _Api(
            church:
                () async => _churchWith(7, {
                  'Római katolikus Szentmise, Csendes': '2026-09-17 18:00:00',
                  'Római katolikus Szentmise latin nyelven':
                      '2026-09-17 18:00:00',
                }),
          ),
        );
        final mass = _item(7, at18, 'Szentmise');

        final details = await loader.fetchMassDetails([mass], _morning);

        expect(details.of(mass), isNull);
      });
    });
  });
}
