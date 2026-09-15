/// Where a cached row came from. The API's mass id does not tell the sources
/// apart, and [CachedMass.info] means something different in each.
enum MassSource {
  /// The one-time bootstrap import; `info` is the export's remark.
  bootstrap,

  /// The details page's 20-day schedule; `info` is the event's title.
  nearbyMasses,

  /// A list endpoint's `misek`, today only; `info` names the event with the
  /// denomination in front and its details after a comma.
  dailyList,
}

/// One concrete mass occurrence. The legacy [Mass] holds a recurrence rule
/// instead, which is why these are separate types.
///
/// Despite the name, a row from the API need not be a mass: see [isMass].
class CachedMass {
  final int? id;

  /// The API's mass id, which repeats across every occurrence of the same
  /// recurring mass, so it cannot identify a row on its own.
  final int? apiMassId;
  final int churchId;
  final DateTime time;
  final String? info;
  final MassSource source;

  CachedMass({
    required this.id,
    required this.apiMassId,
    required this.churchId,
    required this.time,
    required this.info,
    required this.source,
  });
}
