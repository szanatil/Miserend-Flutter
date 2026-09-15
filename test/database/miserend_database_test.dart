import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/database/miserend_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  // 182 days after 1 March 2026 is 30 August 2026.
  final downloadedAt = DateTime(2026, 3, 1, 10, 0);
  final lastValidDay = DateTime(2026, 8, 30, 23, 59);
  final firstExpiredDay = DateTime(2026, 8, 31, 0, 1);

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false));
  });

  tearDown(() async => db.close());

  // The bootstrap import takes the churches alone from an export this old,
  // because its year-less dates would put the masses on the wrong days.
  group('massesExpiredOn', () {
    test('is false on the 182nd day after the download', () {
      final export = MiserendDatabase(db, downloadedAt: downloadedAt);

      expect(export.massesExpiredOn(lastValidDay), isFalse);
    });

    test('is true from the 183rd day after the download on', () {
      final export = MiserendDatabase(db, downloadedAt: downloadedAt);

      expect(export.massesExpiredOn(firstExpiredDay), isTrue);
    });

    test('is true when it is unknown when the export was downloaded', () {
      final export = MiserendDatabase(db, downloadedAt: null);

      expect(export.massesExpiredOn(lastValidDay), isTrue);
    });
  });
}
