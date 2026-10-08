import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/calendar_days.dart';

// The daylight saving changes bite only in a zone that has them: run with
// `TZ=Europe/Budapest flutter test` to see these fail on 24-hour arithmetic.
// In any zone they state what a calendar day is.
void main() {
  group('addCalendarDays', () {
    test('crosses the autumn change onto the next date, not the same one', () {
      // 2026-10-25 is the last Sunday of October: that day has 25 hours.
      final monday = DateTime(2026, 10, 8).addCalendarDays(18);

      expect(monday, DateTime(2026, 10, 26));
      expect(monday.weekday, DateTime.monday);
    });

    test('crosses the spring change onto the next date', () {
      // 2026-03-29 has 23 hours.
      expect(DateTime(2026, 3, 28).addCalendarDays(1), DateTime(2026, 3, 29));
      expect(DateTime(2026, 3, 28).addCalendarDays(2), DateTime(2026, 3, 30));
    });

    test('lands on midnight, whatever the time of day it starts from', () {
      expect(
        DateTime(2026, 12, 31, 18, 30).addCalendarDays(1),
        DateTime(2027, 1, 1),
      );
    });
  });

  group('calendarDaysSince', () {
    test('counts dates, not 24-hour spans, across both changes', () {
      expect(
        DateTime(2026, 10, 26).calendarDaysSince(DateTime(2026, 10, 8)),
        18,
      );
      expect(DateTime(2026, 3, 29).calendarDaysSince(DateTime(2026, 3, 28)), 1);
      expect(
        DateTime(2026, 3, 30, 0, 30).calendarDaysSince(DateTime(2026, 3, 28)),
        2,
      );
    });

    test('ignores the time of day and goes negative for an earlier date', () {
      expect(
        DateTime(
          2026,
          9,
          15,
          23,
          59,
        ).calendarDaysSince(DateTime(2026, 9, 15, 0, 1)),
        0,
      );
      expect(
        DateTime(2026, 9, 14).calendarDaysSince(DateTime(2026, 9, 15)),
        -1,
      );
    });
  });
}
