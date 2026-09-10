/// One concrete mass occurrence. The legacy [Mass] holds a recurrence rule
/// instead, which is why these are separate types.
class CachedMass {
  final int? id;

  /// The API's mass id, which repeats across every occurrence of the same
  /// recurring mass, so it cannot identify a row on its own.
  final int? apiMassId;
  final int churchId;
  final DateTime time;
  final String? info;

  CachedMass({
    required this.id,
    required this.apiMassId,
    required this.churchId,
    required this.time,
    required this.info,
  });
}
