import 'package:miserend/api/nearby_masses_item.dart';
import 'package:miserend/mass_kind.dart';

/// How long after its start a mass is still reachable. Someone who misses more
/// than 10–15 minutes of the mass may no longer receive communion; this is the
/// safe end of that range.
const Duration reachableAfterStart = Duration(minutes: 10);

/// How many churches the list shows.
const int nearestChurchLimit = 10;

/// The earliest start still reachable at [now].
DateTime reachableFrom(DateTime now) => now.subtract(reachableAfterStart);

/// The latest start that still belongs to today's list: tomorrow at 00:00,
/// inclusive, because a midnight mass belongs to the evening before it in
/// people's minds.
DateTime nearestMassesUntil(DateTime now) =>
    DateTime(now.year, now.month, now.day + 1);

/// The nearest masses of CONTEXT.md, chosen from a raw `NearbyMasses`
/// response as it stands at [now].
List<NearbyMassesItem> selectNearestMasses(
  List<NearbyMassesItem> items,
  DateTime now,
) {
  final from = reachableFrom(now);
  final until = nearestMassesUntil(now);
  final masses = items
      .where((m) => massTitles.contains(m.title))
      .where((m) => !m.start.isBefore(from) && !m.start.isAfter(until));

  // Keeping one item per church also collapses the duplicates the API sends
  // (same church, start and title twice), so they need no step of their own.
  final earliestByChurch = <int, NearbyMassesItem>{};
  for (final mass in masses) {
    final kept = earliestByChurch[mass.churchId];
    if (kept == null || mass.start.isBefore(kept.start)) {
      earliestByChurch[mass.churchId] = mass;
    }
  }

  // "Nearest" picks the churches; the list itself reads in time order. The
  // church id breaks the remaining ties, because List.sort is not stable and
  // distances come rounded to two decimals, so which church makes the cut
  // would otherwise change from one minute's re-selection to the next.
  final nearest =
      earliestByChurch.values.toList()..sort((a, b) {
        final byDistance = a.distanceKm.compareTo(b.distanceKm);
        return byDistance != 0 ? byDistance : a.churchId.compareTo(b.churchId);
      });
  return nearest.take(nearestChurchLimit).toList()..sort((a, b) {
    final byStart = a.start.compareTo(b.start);
    if (byStart != 0) return byStart;
    final byDistance = a.distanceKm.compareTo(b.distanceKm);
    return byDistance != 0 ? byDistance : a.churchId.compareTo(b.churchId);
  });
}

/// An ongoing mass has already started but is still reachable.
bool isOngoing(NearbyMassesItem mass, DateTime now) => !mass.start.isAfter(now);

/// How far ahead a start still gets its time until start. Beyond two hours the
/// start alone says enough, and "7 óra 40 perc múlva" in the morning is noise
/// (spec 0008, „Hátralévő idő").
const Duration timeUntilStartLimit = Duration(minutes: 120);

/// The time until start of CONTEXT.md, in whole minutes — „25 perc múlva",
/// „1 óra 5 perc múlva" — or null where there is nothing to say: past
/// [timeUntilStartLimit], or once the mass has started, where the card says
/// „Épp most tart" instead.
///
/// [now] loses its seconds first, so the text changes together with the
/// phone's clock rather than up to a minute after it. A start carrying seconds
/// of its own would then be 0 minutes away; it still reads as 1.
String? timeUntilStart(DateTime start, DateTime now) {
  if (!start.isAfter(now)) return null;
  final wholeMinute = DateTime(
    now.year,
    now.month,
    now.day,
    now.hour,
    now.minute,
  );
  final minutes = start.difference(wholeMinute).inMinutes;
  if (minutes > timeUntilStartLimit.inMinutes) return null;
  if (minutes < 60) return '${minutes < 1 ? 1 : minutes} perc múlva';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours óra múlva' : '$hours óra $rest perc múlva';
}
