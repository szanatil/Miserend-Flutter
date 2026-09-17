import 'package:flutter/material.dart';
import 'package:miserend/church_details/widgets/day_label.dart';
import 'package:miserend/database/cache/adoration.dart';
import 'package:miserend/extentions.dart';
import 'package:miserend/widgets/section_card.dart';

/// The church's adoration windows, grouped by the day they fall on.
///
/// Overlapping entries on the same day are all shown. Church 38 reports both a
/// 00:00–23:59 window and a 09:00–18:00 one for the same day; collapsing them
/// to the narrower would throw away a perpetual adoration, and we cannot tell
/// the two cases apart from the data.
class AdorationCard extends StatelessWidget {
  const AdorationCard({
    super.key,
    required this.adorations,
    required this.today,
  });

  final List<Adoration> adorations;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final byDay = _byDay();
    return SectionCard(
      title: 'Szentségimádás',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final day in byDay.keys) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 2),
              child: Text(
                _dayHeading(day),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final adoration in byDay[day]!) _entry(context, adoration),
          ],
        ],
      ),
    );
  }

  Widget _entry(BuildContext context, Adoration adoration) {
    final kind = adoration.kind?.trim() ?? '';
    final info = adoration.info?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kind.isEmpty ? _range(adoration) : '${_range(adoration)} · $kind',
          ),
          if (info.isNotEmpty)
            Text(
              info,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.apply(color: Colors.black54),
            ),
        ],
      ),
    );
  }

  /// A window that covers the whole day is stated as such — "00:00 – 23:59"
  /// reads as a precise schedule when it means the opposite.
  String _range(Adoration adoration) {
    final start = adoration.start;
    final end = adoration.end;
    if (start == null || end == null) {
      return 'Egész nap';
    }
    final coversDay =
        start.hour == 0 &&
        start.minute == 0 &&
        end.hour == 23 &&
        end.minute >= 59;
    if (coversDay) {
      return 'Egész nap';
    }
    return '${TimeOfDay.fromDateTime(start).to24hours()} – '
        '${TimeOfDay.fromDateTime(end).to24hours()}';
  }

  String _dayHeading(DateTime day) {
    final name = DayLabel.forDate(day, today);
    if (name == 'Ma' || name == 'Holnap') {
      return name;
    }
    return '$name (${DayLabel.date.format(day)})';
  }

  /// Insertion-ordered, so the days come out chronologically.
  Map<DateTime, List<Adoration>> _byDay() {
    final sorted =
        adorations.where((a) => a.start != null).toList()
          ..sort((a, b) => a.start!.compareTo(b.start!));
    final byDay = <DateTime, List<Adoration>>{};
    for (final adoration in sorted) {
      final start = adoration.start!;
      final day = DateTime(start.year, start.month, start.day);
      byDay.putIfAbsent(day, () => <Adoration>[]).add(adoration);
    }
    return byDay;
  }
}
