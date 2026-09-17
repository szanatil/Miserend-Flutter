import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/database/cache/adoration.dart';
import 'package:miserend/database/cache/bootstrap_importer.dart';
import 'package:miserend/database/cache/cache_database.dart';
import 'package:miserend/database/cache/cached_mass.dart';
import 'package:miserend/database/cache/church_details.dart';
import 'package:miserend/database/cache/community.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

ChurchDetails _church(
  int id, {
  String? name = 'Templom',
  bool? isGreek,
  List<Adoration> adorations = const [],
  List<Community> communities = const [],
}) => ChurchDetails(
  id: id,
  name: name,
  commonName: 'Ismert név',
  names: const ['Templom', 'Church'],
  alternativeNames: const ['Alt'],
  country: 'Magyarország',
  diocese: 'Esztergom-Budapest',
  county: 'Budapest',
  city: 'Budapest V. kerület',
  street: 'Március 15. tér',
  gettingThere: null,
  parish: 'Pl&eacute;b&aacute;nos: X',
  description: 'Leírás',
  accessibility: const {'wheelchair': 'no'},
  email: 'iroda@example.com',
  links: const ['http://example.com'],
  languages: const ['hu', 'en'],
  massScheduleNote: null,
  adorations: adorations,
  hasConfession: false,
  communities: communities,
  lat: 47.492233,
  lon: 19.0522943,
  photos: const ['https://miserend.hu/kepek/templomok/38/a.jpg'],
  updatedAt: DateTime(2026, 7, 27),
  localSyncedAt: null,
  isGreek: isGreek,
);

CachedMass _mass(
  int churchId,
  DateTime time, {
  String? info,
  int? apiMassId,
  MassSource source = MassSource.nearbyMasses,
}) => CachedMass(
  id: null,
  apiMassId: apiMassId,
  churchId: churchId,
  time: time,
  info: info,
  source: source,
);

/// A church at a position, with a photo of its own.
ChurchDetails _at(int id, double? lat, double? lon, {String? name}) =>
    BootstrapImporter.churchFromLegacyRow({
      'tid': id,
      'nev': name ?? 'Templom $id',
      'ismertnev': 'Ismert $id',
      'varos': 'Város $id',
      'lat': lat,
      'lng': lon,
      'kep': 'https://miserend.hu/kepek/templomok/$id/a.jpg',
    });

/// The ids [cache]'s search finds for [term], in the order it lists them.
Future<List<int>> _foundIds(CacheDatabase cache, String term) async => [
  for (final church in await cache.searchChurches(term, null)) church.id,
];

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late CacheDatabase cache;

  setUp(() async {
    cache = await CacheDatabase.create(path: inMemoryDatabasePath);
  });

  tearDown(() async => cache.db.close());

  group('schema', () {
    test('creates both cache tables', () async {
      final tables = await cache.db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
      );
      final names = tables.map((row) => row['name']).toList();

      expect(names, containsAll(<String>['churches_cache', 'masses_cache']));
    });

    test('indexes masses by church and time', () async {
      final indexes = await cache.db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'index' "
        "AND tbl_name = 'masses_cache'",
      );

      expect(indexes, isNotEmpty);
    });

    test(
      'upgrading from version 2 keeps the masses and marks their source',
      () async {
        final dir = await Directory.systemTemp.createTemp('cache_upgrade_test');
        addTearDown(() => dir.delete(recursive: true));
        final path = '${dir.path}/cache.sqlite3';

        // Version 2 had no `forras` column; only the details page's schedule
        // carried an API mass id.
        final old = await openDatabase(
          path,
          version: 2,
          onCreate: (db, version) async {
            await db.execute(
              'CREATE TABLE churches_cache(id INTEGER PRIMARY KEY, nev TEXT, '
              'ismertnev TEXT, alternative_names TEXT, varos TEXT)',
            );
            await db.execute(
              'CREATE TABLE masses_cache('
              'id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'api_mass_id INTEGER, '
              'church_id INTEGER NOT NULL, '
              'idopont TEXT NOT NULL, '
              'informacio TEXT)',
            );
            await db.execute(
              'CREATE TABLE sync_state(kulcs TEXT PRIMARY KEY, '
              'idopont TEXT NOT NULL)',
            );
          },
        );
        await old.insert('masses_cache', {
          'api_mass_id': 7,
          'church_id': 38,
          'idopont': '2026-09-20 09:00:00',
          'informacio': 'Szentmise',
        });
        await old.insert('masses_cache', {
          'api_mass_id': null,
          'church_id': 38,
          'idopont': '2026-09-20 18:00:00',
          'informacio': null,
        });
        await old.close();

        final upgraded = await CacheDatabase.create(path: path);
        addTearDown(() => upgraded.db.close());
        final masses = await upgraded.getMassesForChurch(38);

        expect(masses.map((mass) => (mass.time, mass.source)), [
          (DateTime(2026, 9, 20, 9), MassSource.nearbyMasses),
          (DateTime(2026, 9, 20, 18), MassSource.bootstrap),
        ]);
      },
    );

    test(
      'upgrading from version 3 makes the cached churches searchable',
      () async {
        final dir = await Directory.systemTemp.createTemp('cache_upgrade_test');
        addTearDown(() => dir.delete(recursive: true));
        final path = '${dir.path}/cache.sqlite3';

        // Version 3 searched `nev` and `ismertnev` with LIKE, and had no
        // folded search columns.
        final old = await openDatabase(
          path,
          version: 3,
          onCreate: (db, version) async {
            await db.execute(
              'CREATE TABLE churches_cache(id INTEGER PRIMARY KEY, nev TEXT, '
              'ismertnev TEXT, names TEXT, alternative_names TEXT, '
              'varos TEXT, lat REAL, lon REAL, photos TEXT)',
            );
            await db.execute(
              'CREATE TABLE masses_cache('
              'id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'api_mass_id INTEGER, '
              'church_id INTEGER NOT NULL, '
              'idopont TEXT NOT NULL, '
              'informacio TEXT, '
              'forras TEXT NOT NULL)',
            );
            await db.execute(
              'CREATE TABLE sync_state(kulcs TEXT PRIMARY KEY, '
              'idopont TEXT NOT NULL)',
            );
          },
        );
        await old.insert('churches_cache', {
          'id': 1515,
          'nev': 'Budavári Nagyboldogasszony-templom',
          'ismertnev': 'Mátyás-templom',
          'alternative_names': '["Koronázó főtemplom"]',
          'varos': 'Budapest I. kerület',
        });
        await old.insert('churches_cache', {
          'id': 7,
          'nev': null,
          'ismertnev': null,
          'alternative_names': null,
          'varos': null,
        });
        await old.close();

        final upgraded = await CacheDatabase.create(path: path);
        addTearDown(() => upgraded.db.close());

        expect(await _foundIds(upgraded, 'MATYAS'), [1515]);
        expect(await _foundIds(upgraded, 'koronazo'), [1515]);
        expect(await _foundIds(upgraded, 'kerulet'), [1515]);
        expect(await upgraded.searchCities('KERÜLET'), ['Budapest I. kerület']);
      },
    );
  });

  group('churches', () {
    test('returns null for a church it has never seen', () async {
      expect(await cache.getChurch(404), isNull);
    });

    test('round-trips every field, including the JSON ones', () async {
      await cache.upsertChurch(
        _church(
          38,
          adorations: [
            Adoration(
              start: DateTime(2026, 9, 10, 16, 0),
              end: DateTime(2026, 9, 10, 17, 10),
              kind: 'csendes',
              info: 'Kivéve júliusban',
            ),
          ],
          communities: [Community(name: 'Közösség', link: 'http://k.hu')],
        ),
      );

      final stored = (await cache.getChurch(38))!;

      expect(stored.id, 38);
      expect(stored.name, 'Templom');
      expect(stored.commonName, 'Ismert név');
      expect(stored.names, ['Templom', 'Church']);
      expect(stored.alternativeNames, ['Alt']);
      expect(stored.country, 'Magyarország');
      expect(stored.diocese, 'Esztergom-Budapest');
      expect(stored.county, 'Budapest');
      expect(stored.city, 'Budapest V. kerület');
      expect(stored.street, 'Március 15. tér');
      expect(stored.gettingThere, isNull);
      expect(stored.parish, 'Pl&eacute;b&aacute;nos: X');
      expect(stored.description, 'Leírás');
      expect(stored.accessibility, {'wheelchair': 'no'});
      expect(stored.email, 'iroda@example.com');
      expect(stored.links, ['http://example.com']);
      expect(stored.languages, ['hu', 'en']);
      expect(stored.massScheduleNote, isNull);
      expect(stored.hasConfession, isFalse);
      expect(stored.lat, 47.492233);
      expect(stored.lon, 19.0522943);
      expect(stored.photos, ['https://miserend.hu/kepek/templomok/38/a.jpg']);
      expect(stored.updatedAt, DateTime(2026, 7, 27));

      expect(stored.adorations, hasLength(1));
      expect(stored.adorations.single.start, DateTime(2026, 9, 10, 16, 0));
      expect(stored.adorations.single.end, DateTime(2026, 9, 10, 17, 10));
      expect(stored.adorations.single.kind, 'csendes');
      expect(stored.adorations.single.info, 'Kivéve júliusban');

      expect(stored.communities, hasLength(1));
      expect(stored.communities.single.name, 'Közösség');
      expect(stored.communities.single.link, 'http://k.hu');
    });

    test('records when the API last wrote the row', () async {
      final before = DateTime.now();
      await cache.upsertChurch(_church(38));
      final stored = (await cache.getChurch(38))!;

      expect(stored.localSyncedAt, isNotNull);
      expect(
        stored.localSyncedAt!.isBefore(
          before.subtract(const Duration(seconds: 1)),
        ),
        isFalse,
      );
    });

    test('overwrites the existing row instead of adding another', () async {
      await cache.upsertChurch(_church(38, name: 'Régi név'));
      await cache.upsertChurch(_church(38, name: 'Új név'));

      final rows = await cache.db.query('churches_cache');
      expect(rows, hasLength(1));
      expect((await cache.getChurch(38))!.name, 'Új név');
    });

    test(
      'keeps the bootstrap-only isGreek when the API rewrites the row',
      () async {
        await cache.upsertChurch(_church(38, isGreek: true));

        // An API response carries no isGreek at all.
        await cache.upsertChurch(_church(38, name: 'API név', isGreek: null));

        final stored = (await cache.getChurch(38))!;
        expect(stored.name, 'API név');
        expect(stored.isGreek, isTrue);
      },
    );
  });

  group('masses', () {
    test('replaces only the given church, leaving the others alone', () async {
      await cache.replaceMassesForChurch(38, [
        _mass(38, DateTime(2026, 9, 10, 17, 0), info: 'Régi'),
      ]);
      await cache.replaceMassesForChurch(99, [
        _mass(99, DateTime(2026, 9, 10, 9, 0), info: 'Másik templom'),
      ]);

      await cache.replaceMassesForChurch(38, [
        _mass(38, DateTime(2026, 9, 11, 18, 0), info: 'Új', apiMassId: 129807),
      ]);

      final ours = await cache.getMassesForChurch(38);
      expect(ours, hasLength(1));
      expect(ours.single.info, 'Új');
      expect(ours.single.apiMassId, 129807);
      expect(ours.single.time, DateTime(2026, 9, 11, 18, 0));
      expect(ours.single.id, isNotNull);

      final theirs = await cache.getMassesForChurch(99);
      expect(theirs.single.info, 'Másik templom');
    });

    test('returns the masses of the requested range in time order', () async {
      await cache.replaceMassesForChurch(38, [
        _mass(38, DateTime(2026, 9, 12, 18, 0)),
        _mass(38, DateTime(2026, 9, 10, 17, 0)),
        _mass(38, DateTime(2026, 9, 11, 7, 30)),
        _mass(38, DateTime(2026, 9, 30, 17, 0)),
      ]);

      final all = await cache.getMassesForChurch(38);
      expect(all.map((m) => m.time), [
        DateTime(2026, 9, 10, 17, 0),
        DateTime(2026, 9, 11, 7, 30),
        DateTime(2026, 9, 12, 18, 0),
        DateTime(2026, 9, 30, 17, 0),
      ]);

      final ranged = await cache.getMassesForChurch(
        38,
        from: DateTime(2026, 9, 11),
        until: DateTime(2026, 9, 13),
      );
      expect(ranged.map((m) => m.time), [
        DateTime(2026, 9, 11, 7, 30),
        DateTime(2026, 9, 12, 18, 0),
      ]);
    });

    test('is empty for a church with no cached masses', () async {
      expect(await cache.getMassesForChurch(38), isEmpty);
    });
  });

  group('mass source', () {
    test('is stored with every row', () async {
      await cache.importChurches(
        [_at(38, 47.49, 19.05)],
        [
          _mass(
            38,
            DateTime(2026, 9, 10, 9, 0),
            info: 'gitáros',
            source: MassSource.bootstrap,
          ),
        ],
      );
      await cache.replaceMassesForChurch(99, [
        _mass(
          99,
          DateTime(2026, 9, 10, 17, 0),
          info: 'Gyóntatás',
          source: MassSource.nearbyMasses,
        ),
      ]);

      expect(
        (await cache.getMassesForChurch(38)).single.source,
        MassSource.bootstrap,
      );
      expect(
        (await cache.getMassesForChurch(99)).single.source,
        MassSource.nearbyMasses,
      );
    });
  });

  group('near churches', () {
    final today = DateTime(2026, 9, 10);

    test('lists every church with a position, nearest first', () async {
      await cache.importChurches([
        _at(1, 47.60, 19.04),
        _at(2, 47.50, 19.04),
        _at(3, null, null),
        _at(4, 47.55, 19.04),
      ], const []);

      final near = await cache.nearChurches(47.50, 19.04, today);

      expect(near.map((c) => c.id), [2, 4, 1]);
    });

    test('measures east–west distance shorter than north–south', () async {
      // At this latitude a degree of longitude is about two thirds of a
      // degree of latitude, so 0.1° east is nearer than 0.08° north.
      await cache.importChurches([
        _at(1, 47.58, 19.00),
        _at(2, 47.50, 19.10),
      ], const []);

      final near = await cache.nearChurches(47.50, 19.00, today);

      expect(near.map((c) => c.id), [2, 1]);
    });

    test("carries each church's rows of that day, in time order", () async {
      await cache.importChurches(
        [_at(1, 47.50, 19.04), _at(2, 47.51, 19.04)],
        [
          _mass(1, DateTime(2026, 9, 10, 18, 0), source: MassSource.bootstrap),
          _mass(1, DateTime(2026, 9, 10, 7, 0), source: MassSource.bootstrap),
          _mass(1, DateTime(2026, 9, 11, 7, 0), source: MassSource.bootstrap),
          _mass(1, DateTime(2026, 9, 9, 23, 0), source: MassSource.bootstrap),
        ],
      );

      final near = await cache.nearChurches(47.50, 19.04, today);

      expect(near[0].masses.map((m) => m.time), [
        DateTime(2026, 9, 10, 7, 0),
        DateTime(2026, 9, 10, 18, 0),
      ]);
      expect(near[1].masses, isEmpty);
    });

    test('carries what a row shows: names, city, first photo', () async {
      await cache.importChurches([
        _at(7, 47.50, 19.04, name: 'Bazilika'),
      ], const []);

      final entry = (await cache.nearChurches(47.50, 19.04, today)).single;

      expect(entry.name, 'Bazilika');
      expect(entry.commonName, 'Ismert 7');
      expect(entry.city, 'Város 7');
      expect(entry.lat, 47.50);
      expect(entry.lon, 19.04);
      expect(entry.photo, 'https://miserend.hu/kepek/templomok/7/a.jpg');
    });
  });

  group('a minimal answer', () {
    /// What a `minimal` response maps to: none of the fields it leaves out.
    ChurchDetails minimal(
      int id, {
      String name = 'API név',
      double lat = 47.6,
    }) => ChurchDetails(
      id: id,
      name: name,
      commonName: 'API ismert név',
      names: const [],
      alternativeNames: const [],
      country: 'Magyarország',
      diocese: null,
      county: null,
      city: 'API város',
      street: null,
      gettingThere: null,
      parish: null,
      description: null,
      accessibility: null,
      email: null,
      links: const ['http://api.example.com'],
      languages: const [],
      massScheduleNote: null,
      adorations: const [],
      hasConfession: true,
      communities: const [],
      lat: lat,
      lon: 19.1,
      photos: const [],
      updatedAt: DateTime(2026, 9, 1),
      localSyncedAt: null,
      isGreek: null,
    );

    test(
      'overwrites what it carries, corrected coordinates included',
      () async {
        await cache.upsertChurch(_church(38, isGreek: true));

        await cache.upsertChurch(minimal(38, lat: 47.7), minimal: true);

        final stored = (await cache.getChurch(38))!;
        expect(stored.name, 'API név');
        expect(stored.commonName, 'API ismert név');
        expect(stored.city, 'API város');
        expect(stored.lat, 47.7);
        expect(stored.lon, 19.1);
        expect(stored.links, ['http://api.example.com']);
        expect(stored.hasConfession, isTrue);
        expect(stored.updatedAt, DateTime(2026, 9, 1));
        expect(stored.localSyncedAt, isNotNull);
      },
    );

    test('keeps the fields it leaves out, and the greek-rite flag', () async {
      await cache.upsertChurch(_church(38, isGreek: true));

      await cache.upsertChurch(minimal(38), minimal: true);

      final stored = (await cache.getChurch(38))!;
      expect(stored.photos, ['https://miserend.hu/kepek/templomok/38/a.jpg']);
      expect(stored.description, 'Leírás');
      expect(stored.names, ['Templom', 'Church']);
      expect(stored.alternativeNames, ['Alt']);
      expect(stored.email, 'iroda@example.com');
      expect(stored.street, 'Március 15. tér');
      expect(stored.languages, ['hu', 'en']);
      expect(stored.isGreek, isTrue);
    });

    test('is searched by its new name and city, and its kept alternative '
        'names', () async {
      await cache.upsertChurch(_church(38, name: 'Belvárosi templom'));

      await cache.upsertChurch(minimal(38, name: 'Új név'), minimal: true);

      expect(await _foundIds(cache, 'uj nev'), [38]);
      expect(await _foundIds(cache, 'api varos'), [38]);
      expect(await _foundIds(cache, 'alt'), [38]);
      expect(await _foundIds(cache, 'belvarosi'), isEmpty);
      expect(await cache.searchCities('api varos'), ['API város']);
    });

    test('adds a church the cache has never seen', () async {
      await cache.upsertChurch(
        minimal(4242, name: 'Új templom'),
        minimal: true,
      );

      final stored = (await cache.getChurch(4242))!;
      expect(stored.name, 'Új templom');
      expect(stored.photos, isEmpty);
    });
  });

  group('daily masses', () {
    final today = DateTime(2026, 9, 15);

    CachedMass listed(int hour) => _mass(
      38,
      DateTime(2026, 9, 15, hour, 0),
      info: 'Római katolikus Szentmise',
      source: MassSource.dailyList,
    );

    test("replace the day's rows, leaving the other days alone", () async {
      await cache.importChurches(
        [_at(38, 47.49, 19.05)],
        [
          _mass(38, DateTime(2026, 9, 14, 8, 0), source: MassSource.bootstrap),
          _mass(38, DateTime(2026, 9, 15, 8, 0), source: MassSource.bootstrap),
          _mass(38, DateTime(2026, 9, 16, 8, 0), source: MassSource.bootstrap),
        ],
      );

      await cache.replaceDailyMasses(38, today, [listed(7), listed(18)]);

      final stored = await cache.getMassesForChurch(38);
      expect(stored.map((m) => (m.time, m.source)), [
        (DateTime(2026, 9, 14, 8, 0), MassSource.bootstrap),
        (DateTime(2026, 9, 15, 7, 0), MassSource.dailyList),
        (DateTime(2026, 9, 15, 18, 0), MassSource.dailyList),
        (DateTime(2026, 9, 16, 8, 0), MassSource.bootstrap),
      ]);
    });

    test('an empty day empties the day', () async {
      await cache.importChurches(
        [_at(38, 47.49, 19.05)],
        [_mass(38, DateTime(2026, 9, 15, 8, 0), source: MassSource.bootstrap)],
      );

      await cache.replaceDailyMasses(38, today, const []);

      expect(await cache.getMassesForChurch(38), isEmpty);
    });

    test('leave a day the details schedule has filled untouched', () async {
      await cache.replaceMassesForChurch(38, [
        _mass(
          38,
          DateTime(2026, 9, 15, 9, 0),
          info: 'Szentmise',
          source: MassSource.nearbyMasses,
        ),
      ]);

      await cache.replaceDailyMasses(38, today, [listed(7)]);

      final stored = await cache.getMassesForChurch(38);
      expect(stored.map((m) => (m.time, m.source)), [
        (DateTime(2026, 9, 15, 9, 0), MassSource.nearbyMasses),
      ]);
    });
  });

  group('removed churches', () {
    test('are deleted with their masses, and nothing else is', () async {
      await cache.importChurches(
        [_at(1, 47.50, 19.04), _at(2, 47.51, 19.04)],
        [
          _mass(1, DateTime(2026, 9, 15, 8, 0), source: MassSource.bootstrap),
          _mass(2, DateTime(2026, 9, 15, 9, 0), source: MassSource.bootstrap),
        ],
      );

      await cache.deleteChurches([1]);

      expect(await cache.getChurch(1), isNull);
      expect(await cache.getMassesForChurch(1), isEmpty);
      expect(await cache.getChurch(2), isNotNull);
      expect(await cache.getMassesForChurch(2), hasLength(1));
    });
  });

  group('churches by id', () {
    test(
      'lists the ones the cache holds, by name, with the day\'s rows',
      () async {
        await cache.importChurches(
          [
            _at(1, 47.50, 19.04, name: 'Zirci apátság'),
            _at(2, 47.51, 19.04, name: 'Ágota-templom'),
            _at(3, 47.52, 19.04, name: 'Más'),
          ],
          [
            _mass(1, DateTime(2026, 9, 15, 8, 0), source: MassSource.bootstrap),
            _mass(1, DateTime(2026, 9, 16, 8, 0), source: MassSource.bootstrap),
          ],
        );

        final entries = await cache.churchesByIds([
          1,
          2,
          404,
        ], DateTime(2026, 9, 15));

        expect(entries.map((e) => e.name), ['Ágota-templom', 'Zirci apátság']);
        expect(entries.last.masses.map((m) => m.time), [
          DateTime(2026, 9, 15, 8, 0),
        ]);
      },
    );

    test('is empty for no ids', () async {
      expect(
        await cache.churchesByIds(const [], DateTime(2026, 9, 15)),
        isEmpty,
      );
    });
  });

  group('search', () {
    final today = DateTime(2026, 9, 15);

    setUp(() async {
      await cache.importChurches(
        [
          BootstrapImporter.churchFromLegacyRow({
            'tid': 1515,
            'nev': 'Budavári Nagyboldogasszony-templom',
            'ismertnev': 'Mátyás-templom',
            'varos': 'Budapest I. kerület',
          }),
          BootstrapImporter.churchFromLegacyRow({
            'tid': 1155,
            'nev': 'Havas Boldogasszony templom',
            'ismertnev': 'Alsóvárosi templom',
            'varos': 'Szeged',
          }),
          BootstrapImporter.churchFromLegacyRow({
            'tid': 1160,
            'nev': 'Szent Mihály templom',
            'ismertnev': null,
            'varos': 'Szeged',
          }),
          BootstrapImporter.churchFromLegacyRow({
            'tid': 7,
            'nev': '100% templom',
            'ismertnev': null,
            'varos': 'Szegedi tanya',
          }),
        ],
        [
          _mass(
            1155,
            DateTime(2026, 9, 15, 7, 0),
            source: MassSource.bootstrap,
          ),
          _mass(
            1155,
            DateTime(2026, 9, 16, 7, 0),
            source: MassSource.bootstrap,
          ),
        ],
      );
    });

    test('by name finds a part of the name', () async {
      final found = await cache.searchChurches('Boldogasszony', today);

      expect(found.map((c) => c.id), unorderedEquals([1515, 1155]));
    });

    test('by name finds a part of the common name', () async {
      final found = await cache.searchChurches('Mátyás', today);

      expect(found.map((c) => c.id), [1515]);
    });

    test("carries each found church's rows of the day", () async {
      final found = await cache.searchChurches('Havas', today);

      expect(found.single.masses.map((m) => m.time), [
        DateTime(2026, 9, 15, 7, 0),
      ]);
    });

    test('takes the search term literally, wildcards included', () async {
      expect((await cache.searchChurches('100%', today)).map((c) => c.id), [7]);
      expect(await cache.searchChurches('%', today), hasLength(1));
      expect(await cache.searchChurches("'", today), isEmpty);
    });

    test('a city lists the churches of that city, by name', () async {
      final found = await cache.churchesInCity('Szeged', today);

      expect(found.map((c) => c.name), [
        'Havas Boldogasszony templom',
        'Szent Mihály templom',
      ]);
    });

    test('suggests cities by a part of their name, each once', () async {
      expect(
        await cache.searchCities('Szeged'),
        unorderedEquals(['Szeged', 'Szegedi tanya']),
      );
    });

    test('suggests churches without reading their masses', () async {
      final found = await cache.searchChurches('Havas', null);

      expect(found.single.name, 'Havas Boldogasszony templom');
      expect(found.single.masses, isEmpty);
    });

    test('by name ignores case and accents', () async {
      for (final term in ['matyas', 'MÁTYÁS', 'Mátyás', 'MATYAS']) {
        final found = await cache.searchChurches(term, today);

        expect(found.map((c) => c.id), [1515], reason: term);
      }
    });

    test('by name finds a part of an alternative name', () async {
      await cache.upsertChurch(_church(38, name: 'Belvárosi templom'));

      final found = await cache.searchChurches('alt', today);

      expect(found.map((c) => c.id), [38]);
    });

    test('by name finds the churches of a matching city', () async {
      final found = await cache.searchChurches('szeged', today);

      expect(found.map((c) => c.id), unorderedEquals([1155, 1160, 7]));
    });

    test('by name lists name matches before city-only matches', () async {
      await cache.importChurches([
        BootstrapImporter.churchFromLegacyRow({
          'tid': 9,
          'nev': 'Szegedi Szent Mihály',
          'ismertnev': null,
          'varos': 'Tápé',
        }),
      ], const []);

      expect(await _foundIds(cache, 'szeged'), [9, 7, 1155, 1160]);
    });

    test('suggests cities ignoring case and accents, each once', () async {
      expect(await cache.searchCities('KERULET'), ['Budapest I. kerület']);
    });
  });

  group('church locations', () {
    test('are every church with a position', () async {
      await cache.importChurches([
        _at(1, 47.50, 19.04),
        _at(2, null, null),
        _at(3, 0, 0),
        _at(4, 46.25, 20.14),
      ], const []);

      final locations = await cache.churchLocations();

      expect(
        locations.map((l) => (l.id, l.lat, l.lon)),
        unorderedEquals([(1, 47.50, 19.04), (4, 46.25, 20.14)]),
      );
    });
  });
}
