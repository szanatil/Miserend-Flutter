import 'package:miserend/api/api_result.dart';
import 'package:miserend/database/cache/cached_mass.dart';
import 'package:miserend/database/cache/church_details.dart';

/// Everything the church details page draws itself from, in one value.
///
/// The page used to receive only a schedule and render the rest from the
/// legacy [Church] it was handed. Carrying the cached [ChurchDetails] here is
/// what lets the page show the fields the v4 API adds.
class ChurchPageData {
  /// Null only before the cache has ever held this church, which cannot happen
  /// after the bootstrap import unless the church is newer than it.
  final ChurchDetails? church;

  /// One bucket per day, so the day a mass belongs to is its list index.
  final List<List<CachedMass>> massesByDay;

  /// True once a NearbyMasses response has landed, an empty one included.
  /// Until then an empty day means "we have not been told", not "no mass is
  /// held" — and the page has to word it differently, because confusing the
  /// two on a mass-times app is the one mistake worth guarding against.
  final bool scheduleIsFresh;

  /// Why the last attempt to refresh from the API got no answer; null while
  /// it is still running and after it succeeded. The page marks what it shows
  /// as not live only when this is set.
  final ApiFailure? failure;

  /// True once the API has reported the church removed from miserend.hu.
  /// It has then been deleted from the cache and the favorites, and the page
  /// says so in place of the schedule.
  final bool churchGone;

  /// How old the shown data is: when this phone last synced the church, or,
  /// for a church no API response has touched, when the bootstrap import ran.
  final DateTime? dataAsOf;

  /// Whether confession is being heard *right now*.
  ///
  /// `gyontatas` is not an opening-hours field: miserend.hu runs physical
  /// switches in confessionals that report over LoRaWAN, so the value is a
  /// momentary state. It is therefore never taken from the cache — a `true`
  /// stored three days ago would send someone to a church for nothing — and
  /// only ever set from a response that arrived in this session.
  final bool confessionLive;

  const ChurchPageData({
    required this.church,
    required this.massesByDay,
    required this.scheduleIsFresh,
    required this.confessionLive,
    this.failure,
    this.dataAsOf,
    this.churchGone = false,
  });
}
