import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/database/cache/cache_database.dart';
import 'package:miserend/database/cache/church_details.dart';
import 'package:miserend/home/masses/nearest_masses_loader.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
      await cache.upsertChurch(_church(37, photos: const [
        'https://miserend.hu/kepek/templomok/37/elso.jpg',
        'https://miserend.hu/kepek/templomok/37/masodik.jpg',
      ]));
      await cache.upsertChurch(_church(38, photos: const [
        'https://miserend.hu/kepek/templomok/38/elso.jpg',
      ]));
      final loader = NearestMassesLoader(cache: cache);

      expect(await loader.thumbnailUrl(37),
          'https://miserend.hu/kepek/templomok/37/elso.jpg');
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
}
