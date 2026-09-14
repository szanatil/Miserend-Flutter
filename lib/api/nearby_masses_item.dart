/// One item of the v4 `NearbyMasses` response, as it arrives. Despite the
/// endpoint's name it is not necessarily a mass — confession, adoration and
/// the hours come back too, told apart only by [title] (see CONTEXT.md).
class NearbyMassesItem {
  final int churchId;
  final String? churchName;
  final String? city;
  final double? lat;
  final double? lon;

  /// Kilometres from the position the request was made for, as the API
  /// computed it.
  final double distanceKm;

  /// Wall-clock time at the church.
  final DateTime start;
  final String? title;

  const NearbyMassesItem({
    required this.churchId,
    required this.churchName,
    required this.city,
    required this.lat,
    required this.lon,
    required this.distanceKm,
    required this.start,
    required this.title,
  });
}
