import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/api/nearby_masses_item.dart';
import 'package:miserend/home/masses/nearest_masses.dart';

NearbyMassesItem _mass({
  int church = 1,
  double km = 1,
  required DateTime start,
  String title = 'Szentmise',
}) {
  return NearbyMassesItem(
    churchId: church,
    churchName: 'Templom $church',
    city: 'Budapest',
    lat: 47.5,
    lon: 19.0,
    distanceKm: km,
    start: start,
    title: title,
  );
}

DateTime _at(int hour, int minute, [int second = 0]) =>
    DateTime(2026, 9, 14, hour, minute, second);

void main() {
  group('selectNearestMasses', () {
    test('keeps only masses, dropping other liturgical events and unknown '
        'titles', () {
      final now = _at(12, 0);
      final items = [
        _mass(church: 1, start: _at(13, 0), title: 'Szentmise'),
        _mass(church: 2, start: _at(13, 0), title: 'Szent Liturgia'),
        _mass(church: 3, start: _at(13, 0), title: 'Régi rítusú szentmise'),
        _mass(church: 4, start: _at(13, 0), title: 'Vecsernye'),
        _mass(church: 5, start: _at(13, 0), title: 'Utrenye'),
        _mass(church: 6, start: _at(13, 0), title: 'Igeliturgia'),
        _mass(church: 7, start: _at(13, 0), title: 'Gyóntatás'),
        _mass(church: 8, start: _at(13, 0), title: 'Szentségimádás'),
        _mass(church: 9, start: _at(13, 0), title: 'Rózsafüzér'),
        _mass(church: 10, start: _at(13, 0), title: 'Litánia'),
        _mass(church: 11, start: _at(13, 0), title: 'Hittanóra'),
      ];

      final selected = selectNearestMasses(items, now);

      expect(selected.map((m) => m.churchId), unorderedEquals([1, 2, 3]));
    });

    group('a mass stays reachable for exactly 10 minutes after it starts', () {
      final twoPm = [_mass(start: _at(14, 0))];

      test('at 14:05 the 14:00 mass is listed and ongoing', () {
        final selected = selectNearestMasses(twoPm, _at(14, 5));

        expect(selected, hasLength(1));
        expect(isOngoing(selected.single, _at(14, 5)), isTrue);
      });

      test('at 14:10:00 it is still listed', () {
        expect(selectNearestMasses(twoPm, _at(14, 10)), hasLength(1));
      });

      test('at 14:10:01 it is gone', () {
        expect(selectNearestMasses(twoPm, _at(14, 10, 1)), isEmpty);
      });

      test('a mass that has not started yet is not ongoing', () {
        expect(isOngoing(twoPm.single, _at(13, 59)), isFalse);
      });
    });

    test('at 23:40 the midnight mass is listed but a 00:01 one is not', () {
      final items = [
        _mass(church: 1, start: DateTime(2026, 12, 25, 0, 0)),
        _mass(church: 2, start: DateTime(2026, 12, 25, 0, 1)),
      ];

      final selected = selectNearestMasses(
        items,
        DateTime(2026, 12, 24, 23, 40),
      );

      expect(selected.map((m) => m.churchId), [1]);
    });

    test(
      'at 00:05 yesterday\'s 23:55 mass is listed but the 23:50 one is not',
      () {
        final items = [
          _mass(church: 1, start: DateTime(2026, 9, 13, 23, 55)),
          _mass(church: 2, start: DateTime(2026, 9, 13, 23, 50)),
        ];

        final selected = selectNearestMasses(
          items,
          DateTime(2026, 9, 14, 0, 5),
        );

        expect(selected.map((m) => m.churchId), [1]);
      },
    );

    group('each church is listed once, with its earliest reachable mass', () {
      final items = [
        _mass(church: 1, start: _at(18, 30)),
        _mass(church: 1, start: _at(14, 0)),
        _mass(church: 1, start: _at(9, 0)),
      ];

      test('at 14:05 the 14:00 mass wins over the 18:30 one', () {
        final selected = selectNearestMasses(items, _at(14, 5));

        expect(selected.map((m) => m.start), [_at(14, 0)]);
      });

      test('at 14:15 the 18:30 mass takes its place', () {
        final selected = selectNearestMasses(items, _at(14, 15));

        expect(selected.map((m) => m.start), [_at(18, 30)]);
      });
    });

    test(
      'duplicates of the same church, start and title collapse into one',
      () {
        final items = [
          _mass(church: 37, start: _at(18, 0)),
          _mass(church: 37, start: _at(18, 0)),
        ];

        expect(selectNearestMasses(items, _at(12, 0)), hasLength(1));
      },
    );

    test('lists at most the 10 nearest churches, even when the 11th has an '
        'earlier mass', () {
      final items = [
        for (var church = 1; church <= 10; church++)
          _mass(church: church, km: church.toDouble(), start: _at(18, 0)),
        _mass(church: 11, km: 11, start: _at(12, 30)),
      ];

      final selected = selectNearestMasses(items, _at(12, 0));

      expect(selected, hasLength(10));
      expect(selected.map((m) => m.churchId), isNot(contains(11)));
    });

    test('a church whose masses have all passed makes room for the 11th', () {
      final items = [
        _mass(church: 1, km: 1, start: _at(9, 0)),
        for (var church = 2; church <= 11; church++)
          _mass(church: church, km: church.toDouble(), start: _at(18, 0)),
      ];

      final selected = selectNearestMasses(items, _at(12, 0));

      expect(selected.map((m) => m.churchId), containsAll([2, 11]));
      expect(selected.map((m) => m.churchId), isNot(contains(1)));
    });

    test('a tie in distance at the 10th place is settled the same way '
        'whatever order the response came in', () {
      final items = [
        for (var church = 1; church <= 9; church++)
          _mass(church: church, km: church.toDouble(), start: _at(18, 0)),
        _mass(church: 20, km: 9.5, start: _at(18, 0)),
        _mass(church: 10, km: 9.5, start: _at(18, 0)),
      ];

      final forwards = selectNearestMasses(items, _at(12, 0));
      final backwards = selectNearestMasses(
        items.reversed.toList(),
        _at(12, 0),
      );

      expect(forwards.map((m) => m.churchId), contains(10));
      expect(
        forwards.map((m) => m.churchId),
        orderedEquals(backwards.map((m) => m.churchId)),
      );
    });

    test('orders by start, then the nearer church first on the same start', () {
      final items = [
        _mass(church: 1, km: 0.4, start: _at(19, 0)),
        _mass(church: 2, km: 2.5, start: _at(17, 0)),
        _mass(church: 3, km: 0.9, start: _at(18, 0)),
        _mass(church: 4, km: 1.2, start: _at(17, 0)),
      ];

      final selected = selectNearestMasses(items, _at(12, 0));

      expect(selected.map((m) => m.churchId), [4, 2, 3, 1]);
    });
  });

  group('timeUntilStart', () {
    test('in the last second before the start it is 1 minute', () {
      expect(timeUntilStart(_at(18, 0), _at(17, 59, 59)), '1 perc múlva');
    });

    test('a start with seconds in the current minute still reads 1 minute', () {
      expect(timeUntilStart(_at(18, 0, 30), _at(18, 0, 10)), '1 perc múlva');
    });

    test('drops the seconds of now before counting', () {
      expect(timeUntilStart(_at(18, 0), _at(17, 35, 40)), '25 perc múlva');
    });

    test('counts minutes below an hour', () {
      expect(timeUntilStart(_at(18, 0), _at(17, 59)), '1 perc múlva');
      expect(timeUntilStart(_at(18, 0), _at(17, 1)), '59 perc múlva');
    });

    test('a whole hour leaves the minutes out', () {
      expect(timeUntilStart(_at(18, 0), _at(17, 0)), '1 óra múlva');
      expect(timeUntilStart(_at(18, 0), _at(16, 0)), '2 óra múlva');
    });

    test('otherwise gives hours and minutes', () {
      expect(timeUntilStart(_at(18, 5), _at(17, 0)), '1 óra 5 perc múlva');
    });

    test('says nothing from 121 minutes on', () {
      expect(timeUntilStart(_at(18, 1), _at(16, 0)), isNull);
    });

    test('counts across midnight', () {
      expect(
        timeUntilStart(DateTime(2026, 9, 15), _at(23, 30)),
        '30 perc múlva',
      );
    });

    test('says nothing once the mass has started', () {
      expect(timeUntilStart(_at(18, 0), _at(18, 0)), isNull);
      expect(timeUntilStart(_at(18, 0), _at(18, 4)), isNull);
    });
  });
}
