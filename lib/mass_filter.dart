import 'package:miserend/database/mass.dart';

/// Whether a legacy recurrence rule is held on a given day. The bootstrap
/// import turns the export's rules into concrete masses with it.
class MassFilter {
  static bool isMassOnDay(Mass mass, DateTime day) {
    return isOnSameDayOfTheWeek(mass, day) && dateRangeCorrect(mass, day);
  }

  static bool isOnSameDayOfTheWeek(Mass mass, DateTime day) =>
      mass.day == day.weekday || mass.day == 0;

  static bool dateRangeCorrect(Mass mass, DateTime day) {
    final int startDate = mass.startDate ?? 0;
    final int endDate = mass.endDate ?? 0;
    final int dayInDatabaseFormat = (day.month) * 100 + day.day;
    if (startDate < endDate) {
      return startDate <= dayInDatabaseFormat && dayInDatabaseFormat <= endDate;
    } else if (startDate > endDate) {
      return startDate <= dayInDatabaseFormat || dayInDatabaseFormat <= endDate;
    } else {
      return startDate == dayInDatabaseFormat && dayInDatabaseFormat == endDate;
    }
  }
}
