/// Where a church stands: all a map marker needs.
class ChurchLocation {
  const ChurchLocation({
    required this.id,
    required this.lat,
    required this.lon,
  });

  final int id;
  final double lat;
  final double lon;
}
