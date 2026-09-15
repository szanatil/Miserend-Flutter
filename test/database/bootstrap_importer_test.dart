import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/database/cache/bootstrap_importer.dart';
import 'package:miserend/database/cache/cache_database.dart';
import 'package:miserend/database/mass.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Mass _rule(
  int day, {
  int from = 101,
  int to = 1231,
  TimeOfDay time = const TimeOfDay(hour: 17, minute: 0),
  String? comment,
}) =>
    Mass(
      id: 1,
      churchId: 38,
      day: day,
      time: time,
      season: null,
      language: null,
      tags: null,
      period: null,
      weight: null,
      startDate: from,
      endDate: to,
      comment: comment,
    );

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('churchFromLegacyRow', () {
    test('maps the legacy columns onto the API-shaped model', () {
      final church = BootstrapImporter.churchFromLegacyRow({
        'tid': 38,
        'nev': 'Belvárosi Nagyboldogasszony-templom',
        'ismertnev': 'Főplébániatemplom',
        'gorog': 0,
        'lat': 47.492233,
        'lng': 19.0522943,
        'geocim': '1056 Budapest, Március 15. tér 2.',
        'varos': 'Budapest V. kerület',
        'orszag': 'Magyarország',
        'megye': 'Budapest',
        'cim': 'Március 15. tér',
        'megkozelites': 'Metró: M3',
        'kep': 'https://miserend.hu/kepek/templomok/38/a.jpg',
      });

      expect(church.id, 38);
      expect(church.name, 'Belvárosi Nagyboldogasszony-templom');
      expect(church.commonName, 'Főplébániatemplom');
      expect(church.lat, 47.492233);
      expect(church.lon, 19.0522943);
      expect(church.city, 'Budapest V. kerület');
      expect(church.country, 'Magyarország');
      expect(church.county, 'Budapest');
      expect(church.street, 'Március 15. tér');
      expect(church.gettingThere, 'Metró: M3');
      expect(church.photos, ['https://miserend.hu/kepek/templomok/38/a.jpg']);
      expect(church.isGreek, isFalse);
    });

    test('keeps the greek-rite flag, which no API response carries', () {
      final church =
          BootstrapImporter.churchFromLegacyRow({'tid': 1, 'gorog': 1});

      expect(church.isGreek, isTrue);
    });

    test('starts the API-only fields empty', () {
      final church =
          BootstrapImporter.churchFromLegacyRow({'tid': 1, 'gorog': 0});

      expect(church.diocese, isNull);
      expect(church.email, isNull);
      expect(church.description, isNull);
      expect(church.parish, isNull);
      expect(church.accessibility, isNull);
      expect(church.hasConfession, isNull);
      expect(church.links, isEmpty);
      expect(church.languages, isEmpty);
      expect(church.adorations, isEmpty);
      expect(church.communities, isEmpty);
      expect(church.localSyncedAt, isNull);
    });

    test('has no photo when the legacy row carries no image', () {
      expect(
          BootstrapImporter.churchFromLegacyRow({'tid': 1, 'kep': ''}).photos,
          isEmpty);
      expect(
          BootstrapImporter.churchFromLegacyRow({'tid': 1, 'kep': null}).photos,
          isEmpty);
    });
  });

  group('expandMasses', () {
    // A Monday, so the seven-day window runs Mon 7th to Sun 13th.
    final monday = DateTime(2026, 9, 7);

    test('turns a weekly rule into one occurrence per matching weekday', () {
      final masses = BootstrapImporter.expandMasses(
        [_rule(DateTime.wednesday)],
        from: monday,
        days: 7,
      );

      expect(masses.map((m) => m.time), [DateTime(2026, 9, 9, 17, 0)]);
      expect(masses.single.churchId, 38);
      expect(masses.single.apiMassId, isNull);
    });

    test('repeats a rule that is held on any day of the week', () {
      final masses = BootstrapImporter.expandMasses(
        [_rule(0)],
        from: monday,
        days: 7,
      );

      expect(masses, hasLength(7));
      expect(masses.first.time, DateTime(2026, 9, 7, 17, 0));
      expect(masses.last.time, DateTime(2026, 9, 13, 17, 0));
    });

    test('honours a season that wraps around the new year', () {
      final adventOnly = _rule(DateTime.wednesday, from: 1101, to: 228);

      expect(
          BootstrapImporter.expandMasses([adventOnly], from: monday, days: 7),
          isEmpty,
          reason: 'September falls outside a November-to-February season');
      expect(
          BootstrapImporter.expandMasses([adventOnly],
              from: DateTime(2026, 11, 2), days: 7),
          hasLength(1));
      expect(
          BootstrapImporter.expandMasses([adventOnly],
              from: DateTime(2026, 1, 5), days: 7),
          hasLength(1));
    });

    test('keeps a single-day rule to that one date', () {
      // 0909 is the Wednesday inside the window.
      final christmasLike = _rule(0, from: 909, to: 909);

      final masses =
          BootstrapImporter.expandMasses([christmasLike], from: monday, days: 7);

      expect(masses.map((m) => m.time), [DateTime(2026, 9, 9, 17, 0)]);
    });

    test('drops a rule that never falls inside the window', () {
      final masses = BootstrapImporter.expandMasses(
        [_rule(DateTime.wednesday, from: 601, to: 831)],
        from: monday,
        days: 7,
      );

      expect(masses, isEmpty);
    });

    test('sorts the occurrences chronologically', () {
      final masses = BootstrapImporter.expandMasses(
        [
          _rule(DateTime.friday, time: const TimeOfDay(hour: 18, minute: 0)),
          _rule(DateTime.tuesday, time: const TimeOfDay(hour: 7, minute: 30)),
        ],
        from: monday,
        days: 7,
      );

      expect(masses.map((m) => m.time), [
        DateTime(2026, 9, 8, 7, 30),
        DateTime(2026, 9, 11, 18, 0),
      ]);
    });

    test('collapses rules that land on the same time with the same note', () {
      final masses = BootstrapImporter.expandMasses(
        [_rule(DateTime.wednesday), _rule(DateTime.wednesday)],
        from: monday,
        days: 7,
      );

      expect(masses, hasLength(1));
    });

    test('keeps two masses that start at once but differ otherwise', () {
      final masses = BootstrapImporter.expandMasses(
        [
          _rule(DateTime.wednesday, comment: 'magyar'),
          _rule(DateTime.wednesday, comment: 'angol'),
        ],
        from: monday,
        days: 7,
      );

      expect(masses, hasLength(2));
      expect(masses.map((m) => m.info), containsAll(['magyar', 'angol']));
    });

    test('skips a rule with no time at all', () {
      final untimed = Mass(
        id: 1,
        churchId: 38,
        day: DateTime.wednesday,
        time: null,
        season: null,
        language: null,
        tags: null,
        period: null,
        weight: null,
        startDate: 101,
        endDate: 1231,
        comment: null,
      );

      expect(BootstrapImporter.expandMasses([untimed], from: monday, days: 7),
          isEmpty);
    });
  });

  group('run', () {
    late Database legacy;
    late CacheDatabase cache;

    setUp(() async {
      // Not a single instance, so that it stays a different database from the
      // cache, which opens the same in-memory path.
      legacy = await databaseFactory.openDatabase(inMemoryDatabasePath,
          options: OpenDatabaseOptions(singleInstance: false));
      await legacy.execute('CREATE TABLE templomok (tid INTEGER PRIMARY KEY, '
          'nev TEXT, ismertnev TEXT, gorog INTEGER, lat REAL, lng REAL, '
          'geocim TEXT, varos TEXT, orszag TEXT, megye TEXT, cim TEXT, '
          'megkozelites TEXT, kep TEXT)');
      await legacy.execute('CREATE TABLE misek (mid INTEGER PRIMARY KEY, '
          'tid INTEGER, nap INTEGER, ido TEXT, idoszak TEXT, nyelv TEXT, '
          'milyen TEXT, periodus TEXT, suly INTEGER, datumtol INT, '
          'datumig INT, megjegyzes TEXT)');

      cache = await CacheDatabase.create(path: inMemoryDatabasePath);
    });

    tearDown(() async {
      await legacy.close();
      await cache.db.close();
    });

    Future<void> insertChurch(int tid, String name) =>
        legacy.insert('templomok', {
          'tid': tid,
          'nev': name,
          'gorog': 0,
          'lat': 47.5,
          'lng': 19.0,
          'kep': '',
        });

    Future<void> insertRule(int mid, int tid, int day, String time) =>
        legacy.insert('misek', {
          'mid': mid,
          'tid': tid,
          'nap': day,
          'ido': time,
          'datumtol': 101,
          'datumig': 1231,
        });

    test('fills the cache from the legacy tables', () async {
      await insertChurch(38, 'Belvárosi');
      await insertChurch(99, 'Másik');
      await insertRule(1, 38, DateTime.wednesday, '17:00:00');
      await insertRule(2, 99, DateTime.friday, '18:00:00');

      await BootstrapImporter.run(
        legacy: legacy,
        cache: cache,
        from: DateTime(2026, 9, 7),
        days: 7,
      );

      expect((await cache.getChurch(38))!.name, 'Belvárosi');
      expect((await cache.getChurch(99))!.name, 'Másik');

      final masses = await cache.getMassesForChurch(38);
      expect(masses.map((m) => m.time), [DateTime(2026, 9, 9, 17, 0)]);
      expect(await cache.getMassesForChurch(99), hasLength(1));
    });

    test('marks the rows as never synced from the API', () async {
      await insertChurch(38, 'Belvárosi');

      await BootstrapImporter.run(
          legacy: legacy, cache: cache, from: DateTime(2026, 9, 7));

      expect((await cache.getChurch(38))!.localSyncedAt, isNull,
          reason: 'only an API response may stamp local_synced_at');
    });

    test('imports the thirty days starting on the install day', () async {
      await insertChurch(38, 'Belvárosi');
      await insertRule(1, 38, 0, '17:00:00');

      await BootstrapImporter.run(
        legacy: legacy,
        cache: cache,
        from: DateTime(2026, 9, 7, 14, 30),
      );

      final masses = await cache.getMassesForChurch(38);
      expect(masses, hasLength(30));
      expect(masses.first.time, DateTime(2026, 9, 7, 17, 0));
      expect(masses.last.time, DateTime(2026, 10, 6, 17, 0));
    });

    test('leaves the same result behind when it runs twice', () async {
      await insertChurch(38, 'Belvárosi');
      await insertRule(1, 38, DateTime.wednesday, '17:00:00');

      await BootstrapImporter.run(
          legacy: legacy, cache: cache, from: DateTime(2026, 9, 7), days: 7);
      await BootstrapImporter.run(
          legacy: legacy, cache: cache, from: DateTime(2026, 9, 7), days: 7);

      expect(await cache.db.query('churches_cache'), hasLength(1));
      expect(await cache.getMassesForChurch(38), hasLength(1));
    });
  });
}
