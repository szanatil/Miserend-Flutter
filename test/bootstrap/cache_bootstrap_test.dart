import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miserend/bootstrap/cache_bootstrap.dart';
import 'package:miserend/database/cache/cache_database.dart';
import 'package:miserend/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Where the endpoint redirects to, as miserend.hu does.
final Uri _file = Uri.parse(
  'https://miserend.hu/fajlok/sqlite/miserend.sqlite3',
);

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory downloads;
  late CacheDatabase cache;

  /// A small but real export: one church with a daily mass.
  late List<int> export;

  setUpAll(() async {
    final source = Directory.systemTemp.createTempSync('export');
    final path = '${source.path}/export.sqlite3';
    final db = await databaseFactory.openDatabase(path);
    await db.execute(
      'CREATE TABLE templomok (tid INTEGER PRIMARY KEY, nev TEXT, '
      'ismertnev TEXT, gorog INTEGER, lat REAL, lng REAL, varos TEXT, '
      'orszag TEXT, megye TEXT, cim TEXT, megkozelites TEXT, kep TEXT)',
    );
    await db.execute(
      'CREATE TABLE misek (mid INTEGER PRIMARY KEY, tid INTEGER, nap INTEGER, '
      'ido TEXT, idoszak TEXT, nyelv TEXT, milyen TEXT, periodus TEXT, '
      'suly INTEGER, datumtol INT, datumig INT, megjegyzes TEXT)',
    );
    await db.insert('templomok', {'tid': 38, 'nev': 'Belvárosi', 'gorog': 0});
    await db.insert('misek', {
      'mid': 1,
      'tid': 38,
      'nap': 0,
      'ido': '17:00:00',
      'datumtol': 101,
      'datumig': 1231,
    });
    await db.close();
    export = File(path).readAsBytesSync();
    source.deleteSync(recursive: true);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    downloads = Directory.systemTemp.createTempSync('downloads');
    cache = await CacheDatabase.create(path: inMemoryDatabasePath);
  });

  tearDown(() async {
    await cache.db.close();
    downloads.deleteSync(recursive: true);
  });

  File downloaded() => File('${downloads.path}/miserend.sqlite3');

  CacheBootstrap bootstrapWith(http.Client client) => CacheBootstrap(
    client: client,
    cache: cache,
    directory: () async => downloads.path,
    clock: () => DateTime(2026, 10, 28, 9, 0),
  );

  /// Redirects the endpoint to [_file], which [answer] serves.
  http.Client serving(
    Future<http.StreamedResponse> Function(http.BaseRequest request) answer,
  ) => MockClient.streaming((request, _) async {
    if (request.url == CacheBootstrap.exportUrl) {
      return http.StreamedResponse(
        const Stream.empty(),
        HttpStatus.found,
        headers: {'location': _file.toString()},
      );
    }
    return answer(request);
  });

  /// [export] in two chunks, with its length.
  http.Client servingExport() => serving(
    (request) async => http.StreamedResponse(
      Stream.fromIterable([
        export.sublist(0, export.length ~/ 2),
        export.sublist(export.length ~/ 2),
      ]),
      HttpStatus.ok,
      contentLength: export.length,
    ),
  );

  group('the size', () {
    test('is the file\'s, after the redirect', () async {
      final methods = <String>[];
      final bootstrap = bootstrapWith(
        MockClient.streaming((request, _) async {
          methods.add(request.method);
          if (request.url == CacheBootstrap.exportUrl) {
            return http.StreamedResponse(
              const Stream.empty(),
              HttpStatus.found,
              headers: {'location': _file.toString()},
            );
          }
          expect(request.url, _file);
          return http.StreamedResponse(
            const Stream.empty(),
            HttpStatus.ok,
            headers: {'content-length': '21800000'},
          );
        }),
      );

      expect(await bootstrap.exportSize(), 21800000);
      expect(methods, ['HEAD', 'HEAD']);
    });

    testWidgets('is unavailable when no answer comes in 5 s', (tester) async {
      final bootstrap = bootstrapWith(
        MockClient.streaming(
          (request, _) => Completer<http.StreamedResponse>().future,
        ),
      );

      final size = bootstrap.exportSize();
      await tester.pump(const Duration(seconds: 5));

      expect(await size, isNull);
    });

    test('is unavailable when the server fails', () async {
      final bootstrap = bootstrapWith(
        serving(
          (request) async => http.StreamedResponse(
            const Stream.empty(),
            HttpStatus.internalServerError,
          ),
        ),
      );

      expect(await bootstrap.exportSize(), isNull);
    });
  });

  group('a run', () {
    test('downloads, imports, and is done, in that order', () async {
      final bootstrap = bootstrapWith(servingExport());

      final progress = await bootstrap.run().toList();

      expect(progress, [
        isA<BootstrapDownloading>()
            .having((p) => p.received, 'received', export.length ~/ 2)
            .having((p) => p.total, 'total', export.length),
        isA<BootstrapDownloading>().having(
          (p) => p.received,
          'received',
          export.length,
        ),
        isA<BootstrapImporting>(),
        isA<BootstrapDone>(),
      ]);
      expect((await cache.getChurch(38))!.name, 'Belvárosi');
      expect(await cache.getMassesForChurch(38), hasLength(30));
    });

    test('that succeeds deletes the file and is done for good', () async {
      final bootstrap = bootstrapWith(servingExport());

      await bootstrap.run().last;

      expect(downloaded().existsSync(), isFalse);
      expect(bootstrap.done.value, isTrue);
      expect(await Preferences.isCacheBootstrapped(), isTrue);
    });

    test('stopped during the download deletes the file, is not done, and '
        'counts as declined', () async {
      final chunks = StreamController<List<int>>();
      final bootstrap = bootstrapWith(
        serving(
          (request) async => http.StreamedResponse(
            chunks.stream,
            HttpStatus.ok,
            contentLength: export.length,
          ),
        ),
      );

      final progress = <BootstrapProgress>[];
      final ended = Completer<void>();
      bootstrap.run().listen(progress.add, onDone: ended.complete);
      chunks.add(export.sublist(0, 100));
      while (progress.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(downloaded().existsSync(), isTrue);

      bootstrap.cancel();
      await ended.future;

      expect(progress.last, isA<BootstrapCancelled>());
      expect(downloaded().existsSync(), isFalse);
      expect(bootstrap.done.value, isFalse);
      expect(bootstrap.declined, isTrue);
      expect(await Preferences.isBootstrapDeclined(), isTrue);
      expect(await cache.getChurch(38), isNull);
      await chunks.close();
    });

    test('that fails to download is not declined', () async {
      final bootstrap = bootstrapWith(
        serving(
          (request) async => http.StreamedResponse(
            const Stream.empty(),
            HttpStatus.internalServerError,
          ),
        ),
      );

      expect(await bootstrap.run().last, isA<BootstrapFailed>());
      expect(bootstrap.done.value, isFalse);
      expect(bootstrap.declined, isFalse);
      expect(await Preferences.isBootstrapDeclined(), isFalse);
    });

    test('that fails to import deletes the file and is not declined', () async {
      final bootstrap = bootstrapWith(
        serving(
          (request) async => http.StreamedResponse(
            Stream.value('nem SQLite'.codeUnits),
            HttpStatus.ok,
          ),
        ),
      );

      expect(await bootstrap.run().last, isA<BootstrapFailed>());
      expect(downloaded().existsSync(), isFalse);
      expect(bootstrap.done.value, isFalse);
      expect(bootstrap.declined, isFalse);
    });
  });

  group('restore', () {
    test('reads what earlier starts stored', () async {
      SharedPreferences.setMockInitialValues({
        'CACHE_BOOTSTRAPPED': true,
        'BOOTSTRAP_DECLINED': true,
      });
      final bootstrap = bootstrapWith(servingExport());

      await bootstrap.restore();

      expect(bootstrap.done.value, isTrue);
      expect(bootstrap.declined, isTrue);
    });

    test('deletes an export an earlier start left behind', () async {
      downloaded().writeAsBytesSync(export);

      await bootstrapWith(servingExport()).restore();

      expect(downloaded().existsSync(), isFalse);
    });
  });
}
