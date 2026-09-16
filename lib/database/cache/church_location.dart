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

  /// Whether ([lat], [lon]) says where a church stands. Churches without a
  /// position come as nulls or as (0, 0); neither may get a marker or a
  /// distance, so both follow this one rule.
  static bool isKnown(double? lat, double? lon) =>
      lat != null && lon != null && !(lat == 0 && lon == 0);

  /// [isKnown] as the cache's SQL condition on its `lat` and `lon` columns.
  static const String knownSql =
      'lat IS NOT NULL AND lon IS NOT NULL AND NOT (lat = 0 AND lon = 0)';
}
