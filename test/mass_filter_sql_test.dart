import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/database/mass.dart';
import 'package:miserend/mass_filter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Mass _mass(int day, int from, int to) => Mass(
      id: 0,
      churchId: 0,
      day: day,
      time: const TimeOfDay(hour: 9, minute: 0),
      season: null,
      language: null,
      tags: null,
      period: null,
      weight: null,
      startDate: from,
      endDate: to,
      comment: null,
    );

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute(
        'CREATE TABLE misek (mid INTEGER PRIMARY KEY, nap INTEGER, '
        'datumtol INT, datumig INT)');
  });

  tearDown(() async => db.close());

  test('sqlForDay accepts exactly the rows isMassOnDay accepts', () async {
    // Every shape the Dart filter distinguishes: open range, wrapping range
    // across new year, single day, and each weekday including the 0 wildcard.
    const ranges = <List<int>>[
      [0, 0],
      [101, 1231],
      [601, 831],
      [1101, 228],
      [903, 903],
      [902, 902],
      [903, 101],
      [1231, 101],
    ];

    final masses = <Mass>[];
    var id = 0;
    for (final day in [0, 1, 2, 3, 4, 5, 6, 7]) {
      for (final range in ranges) {
        id++;
        masses.add(_mass(day, range[0], range[1]));
        await db.insert('misek', {
          'mid': id,
          'nap': day,
          'datumtol': range[0],
          'datumig': range[1],
        });
      }
    }

    for (final probe in [
      DateTime(2026, 9, 3),
      DateTime(2026, 1, 1),
      DateTime(2026, 12, 31),
      DateTime(2026, 7, 4),
      DateTime(2026, 2, 28),
      DateTime(2026, 11, 1),
    ]) {
      final expected = <int>[];
      for (var i = 0; i < masses.length; i++) {
        if (MassFilter.isMassOnDay(masses[i], probe)) expected.add(i + 1);
      }

      final rows = await db.rawQuery('SELECT mid FROM misek AS m WHERE '
          '${MassFilter.sqlForDay(probe)} ORDER BY mid');
      final actual = rows.map((r) => r['mid'] as int).toList();

      expect(actual, expected, reason: 'mismatch on $probe');
    }
  });
}
