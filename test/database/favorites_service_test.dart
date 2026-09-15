import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/database/local_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory dir;

  // The service opens its database by name, so each test gets its own folder
  // rather than the one the page tests share.
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('favorites_service_test');
    await databaseFactory.setDatabasesPath(dir.path);
  });

  tearDown(() async => dir.delete(recursive: true));

  Future<FavoritesService> loadedService() async {
    final service = FavoritesService();
    for (var i = 0; i < 400 && !service.loaded; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(service.loaded, isTrue);
    return service;
  }

  group('removeAll', () {
    test('drops the favorite records of churches removed from miserend.hu, '
        'for the next start too', () async {
      final service = await loadedService();
      for (final churchId in [1, 2, 3]) {
        await service.toggle(churchId);
      }
      var notified = 0;
      service.addListener(() => notified++);

      await service.removeAll([1, 3, 99]);

      expect(service.favorites.map((f) => f.churchId), [2]);
      expect(notified, 1);
      final stored = await (await LocalDatabase.create()).getFavorites();
      expect(stored.map((f) => f.churchId), [2]);
    });

    test('leaves the list alone when none of them is a favorite', () async {
      final service = await loadedService();
      await service.toggle(2);
      var notified = 0;
      service.addListener(() => notified++);

      await service.removeAll([1, 3]);

      expect(service.favorites.map((f) => f.churchId), [2]);
      expect(notified, 0);
    });
  });
}
