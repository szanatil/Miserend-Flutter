/// Day arithmetic by the calendar. A day is not always 24 hours: the day the
/// clocks go back has 25 and the day they go forward has 23, so adding
/// `Duration(days: n)` to a midnight, or dividing a difference by 24 hours,
/// lands on the wrong date around a daylight saving change.
extension CalendarDays on DateTime {
  /// Midnight of the date [days] calendar days after this one's.
  DateTime addCalendarDays(int days) => DateTime(year, month, day + days);

  /// How many calendar days this date is after [other]'s, whatever the time
  /// of day on either; negative for an earlier date. Counted on UTC dates,
  /// which have no daylight saving.
  int calendarDaysSince(DateTime other) =>
      DateTime.utc(
        year,
        month,
        day,
      ).difference(DateTime.utc(other.year, other.month, other.day)).inDays;
}
