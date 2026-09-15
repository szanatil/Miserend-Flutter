import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/database/church_with_masses.dart';
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
    await db.execute('CREATE TABLE templomok (tid INTEGER PRIMARY KEY, '
        'nev TEXT, ismertnev TEXT, gorog INTEGER, lat REAL, lng REAL, '
        'geocim TEXT, varos TEXT, orszag TEXT, megye TEXT, cim TEXT, '
        'megkozelites TEXT, kep TEXT)');
    await db.execute('CREATE TABLE misek (mid INTEGER PRIMARY KEY, '
        'tid INTEGER, nap INTEGER, ido TEXT, idoszak TEXT, nyelv TEXT, '
        'milyen TEXT, periodus TEXT, suly INTEGER, datumtol INT, '
        'datumig INT, megjegyzes TEXT)');

    await db.insert('templomok', {
      'tid': 38,
      'nev': 'Belvárosi Nagyboldogasszony-templom',
      'gorog': 0,
      'lat': 47.492233,
      'lng': 19.0522943,
      'varos': 'Budapest',
    });
    // Held every day of the year.
    await db.insert('misek', {
      'mid': 1,
      'tid': 38,
      'nap': 0,
      'ido': '17:00:00',
      'periodus': '0',
      'datumtol': 101,
      'datumig': 1231,
    });
  });

  tearDown(() async => db.close());

  MiserendDatabase export() => MiserendDatabase(db, downloadedAt: downloadedAt);

  test('shows the masses on the 182nd day after the download', () async {
    final church =
        (await export().getChurches([38], lastValidDay)).single;

    expect(church.masses, hasLength(1));
    expect(church.massesExpired, isFalse);
  });

  test('hides the masses from the 183rd day after the download on', () async {
    final church =
        (await export().getChurches([38], firstExpiredDay)).single;

    expect(church.masses, isEmpty);
    expect(church.massesExpired, isTrue);
    expect(church.church.name, 'Belvárosi Nagyboldogasszony-templom',
        reason: 'the churches themselves stay visible');
  });

  test('hides the masses on every screen that still reads the export',
      () async {
    final database = export();
    final screens = <String, Future<List<ChurchWithMasses>>>{
      'favorites': database.getChurches([38], firstExpiredDay),
      'nearby': database.getCloseChurchesWithMasses(
          47.5, 19.05, firstExpiredDay),
      'search': database.getChurchesWithMassesForSearchTerm(
          'Nagyboldogasszony', firstExpiredDay),
      'city': database.getChurchesWithMassesForCity(
          'Budapest', firstExpiredDay),
    };

    for (final entry in screens.entries) {
      final church = (await entry.value).single;
      expect(church.masses, isEmpty, reason: entry.key);
      expect(church.massesExpired, isTrue, reason: entry.key);
    }
  });

  test('hides the masses when it is unknown when the export was downloaded',
      () async {
    final database = MiserendDatabase(db, downloadedAt: null);

    final church = (await database.getChurches([38], lastValidDay)).single;

    expect(church.masses, isEmpty);
    expect(church.massesExpired, isTrue);
  });
}
