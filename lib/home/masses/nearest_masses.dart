import 'package:miserend/api/nearby_masses_item.dart';
import 'package:miserend/database/cache/cached_mass.dart';
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
  final masses =
      items
          .where((m) => massTitles.contains(m.title))
          .where((m) => !m.start.isBefore(from) && !m.start.isAfter(until))
          .toList();

  // "Nearest" picks the churches, and every one of their masses goes on the
  // list, which reads in time order.
  final nearestChurches = _nearestChurchIds(masses);
  return masses.where((m) => nearestChurches.contains(m.churchId)).toList()
    ..sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      if (byStart != 0) return byStart;
      final byDistance = a.distanceKm.compareTo(b.distanceKm);
      return byDistance != 0 ? byDistance : a.churchId.compareTo(b.churchId);
    });
}

/// The [nearestChurchLimit] churches nearest the position among those holding
/// one of [masses]. The church id breaks ties, because distances come rounded
/// to two decimals, and which church makes the cut must not change from one
/// minute's re-selection to the next.
Set<int> _nearestChurchIds(List<NearbyMassesItem> masses) {
  // Every item of a church carries the same distance.
  final distanceOf = {
    for (final mass in masses) mass.churchId: mass.distanceKm,
  };
  final byDistance =
      distanceOf.keys.toList()..sort((a, b) {
        final byKm = distanceOf[a]!.compareTo(distanceOf[b]!);
        return byKm != 0 ? byKm : a.compareTo(b);
      });
  return byDistance.take(nearestChurchLimit).toSet();
}

/// The mass details (CONTEXT.md, „Mise jellemzője") of the nearest masses.
/// `NearbyMasses` does not carry them, so they are read off the churches'
/// schedules for today and matched to a mass by church and start (spec 0011,
/// „Párosítás").
class MassDetails {
  const MassDetails([this._dailyMasses = const {}]);

  /// Today's schedule rows of each church asked about.
  final Map<int, List<CachedMass>> _dailyMasses;

  /// The detail of [mass], or null: when it has none, when its church was not
  /// asked about, or when the schedule does not say which description is its
  /// own. Of several masses starting together, the one of the same kind as
  /// the title is taken.
  String? of(NearbyMassesItem mass) {
    final described = [
      for (final row in _dailyMasses[mass.churchId] ?? const <CachedMass>[])
        if (row.time == mass.start)
          if (describeMass(row.info) case final description?) description,
    ];
    final candidates =
        described.length > 1
            ? described.where((d) => d.title == mass.title).toList()
            : described;
    return candidates.length == 1 ? candidates.single.detail : null;
  }

  /// These details together with [other]'s, [other] winning for a church
  /// both hold: a newer schedule replaces an older one.
  MassDetails merged(MassDetails other) =>
      MassDetails({..._dailyMasses, ...other._dailyMasses});
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
