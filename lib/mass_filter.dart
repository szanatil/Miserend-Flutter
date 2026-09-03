import 'package:miserend/database/mass.dart';
import 'package:miserend/database/mass_with_church.dart';

class MassFilter {

  static List<Mass> filterMassListForDay(List<Mass> masses, DateTime day) => masses.where((m) => isMassOnDay(m, day)).toList();

  static List<MassWithChurch> filterMassWithChurchListForDay(List<MassWithChurch> masses, DateTime day) => masses.where((m) => isMassOnDay(m.mass, day)).toList();

  /// SQL predicate equivalent to [isMassOnDay], for the mass table aliased as
  /// [alias]. The list pages only ever render one day, so pushing this into
  /// the query keeps ~280k irrelevant mass rows out of the result set instead
  /// of decoding them and dropping them here. Both filters must agree, which
  /// is why they live side by side.
  static String sqlForDay(DateTime day, {String alias = 'm'}) {
    final int weekday = day.weekday;
    final int date = day.month * 100 + day.day;
    final String from = 'COALESCE($alias.datumtol, 0)';
    final String to = 'COALESCE($alias.datumig, 0)';
    return '($alias.nap = $weekday OR $alias.nap = 0) AND ('
        '($from < $to AND $from <= $date AND $date <= $to) OR '
        '($from > $to AND ($from <= $date OR $date <= $to)) OR '
        '($from = $to AND $from = $date))';
  }

  static bool isMassOnDay(Mass mass, DateTime day) {
    return isOnSameDayOfTheWeek(mass, day) && dateRangeCorrect(mass, day);
  }

  static bool isOnSameDayOfTheWeek(Mass mass, DateTime day) => mass.day == day.weekday || mass.day == 0;

  static bool dateRangeCorrect(Mass mass, DateTime day) {
    int startDate = mass.startDate ?? 0;
    int endDate = mass.endDate ?? 0;
    int dayInDatabaseFormat = (day.month) * 100 + day.day;
    if (startDate < endDate) {
      return startDate <= dayInDatabaseFormat && dayInDatabaseFormat <= endDate;
    } else if (startDate > endDate){
      return startDate <= dayInDatabaseFormat || dayInDatabaseFormat <= endDate;
    } else {
      return startDate == dayInDatabaseFormat && dayInDatabaseFormat == endDate;
    }
  }
}