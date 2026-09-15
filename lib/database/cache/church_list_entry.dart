import 'package:miserend/database/cache/cached_mass.dart';

/// One row of a church list: only what the row draws, so that a list of every
/// church stays cheap to read.
class ChurchListEntry {
  final int id;
  final String? name;
  final String? commonName;
  final String? city;
  final double? lat;
  final double? lon;

  /// The first cached photo, if any.
  final String? photo;

  /// The church's cached rows for the day the list was read for, masses or
  /// not; the row picks the masses out.
  final List<CachedMass> masses;

  const ChurchListEntry({
    required this.id,
    required this.name,
    required this.commonName,
    required this.city,
    required this.lat,
    required this.lon,
    required this.photo,
    required this.masses,
  });
}
