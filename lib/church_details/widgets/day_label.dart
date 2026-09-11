import 'package:intl/intl.dart';

/// Names a date the way the page's schedule and adoration sections both need.
///
/// Kept out of the widgets so the two cannot drift into calling the same day
/// different things.
class DayLabel {
  static const List<String> weekdays = [
    'Hétfő',
    'Kedd',
    'Szerda',
    'Csütörtök',
    'Péntek',
    'Szombat',
    'Vasárnap',
  ];

  /// Plain numeric, so no locale data has to be initialised for `intl`.
  static final DateFormat date = DateFormat('yyyy. MM. dd.');

  /// "Ma" and "Holnap" carry the date on their own; anything further out needs
  /// the weekday name, which repeats every seven days and so is ambiguous
  /// without it.
  static String forDate(DateTime day, DateTime today) {
    final offset = _midnight(day).difference(_midnight(today)).inDays;
    if (offset == 0) return 'Ma';
    if (offset == 1) return 'Holnap';
    return weekdays[day.weekday - 1];
  }

  static DateTime _midnight(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
