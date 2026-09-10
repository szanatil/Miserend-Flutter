import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/database/cache/adoration.dart';
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
}) =>
    ChurchDetails(
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

CachedMass _mass(int churchId, DateTime time, {String? info, int? apiMassId}) =>
    CachedMass(
      id: null,
      apiMassId: apiMassId,
      churchId: churchId,
      time: time,
      info: info,
    );

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
          "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name");
      final names = tables.map((row) => row['name']).toList();

      expect(names, containsAll(<String>['churches_cache', 'masses_cache']));
    });

    test('indexes masses by church and time', () async {
      final indexes = await cache.db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND tbl_name = 'masses_cache'");

      expect(indexes, isNotEmpty);
    });
  });

  group('churches', () {
    test('returns null for a church it has never seen', () async {
      expect(await cache.getChurch(404), isNull);
    });

    test('round-trips every field, including the JSON ones', () async {
      await cache.upsertChurch(_church(
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
      ));

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
          stored.localSyncedAt!
              .isBefore(before.subtract(const Duration(seconds: 1))),
          isFalse);
    });

    test('overwrites the existing row instead of adding another', () async {
      await cache.upsertChurch(_church(38, name: 'Régi név'));
      await cache.upsertChurch(_church(38, name: 'Új név'));

      final rows = await cache.db.query('churches_cache');
      expect(rows, hasLength(1));
      expect((await cache.getChurch(38))!.name, 'Új név');
    });

    test('keeps the bootstrap-only isGreek when the API rewrites the row',
        () async {
      await cache.upsertChurch(_church(38, isGreek: true));

      // An API response carries no isGreek at all.
      await cache.upsertChurch(_church(38, name: 'API név', isGreek: null));

      final stored = (await cache.getChurch(38))!;
      expect(stored.name, 'API név');
      expect(stored.isGreek, isTrue);
    });
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
}
