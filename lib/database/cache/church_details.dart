import 'package:miserend/database/cache/adoration.dart';
import 'package:miserend/database/cache/community.dart';

/// A church as the v4 API describes it. Distinct from [Church], which carries
/// only the columns the legacy SQLite export ships.
class ChurchDetails {
  final int id;
  final String? name;
  final String? commonName;
  final List<String> names;
  final List<String> alternativeNames;
  final String? country;
  final String? diocese;
  final String? county;
  final String? city;
  final String? street;
  final String? gettingThere;
  final String? parish;
  final String? description;
  final Map<String, dynamic>? accessibility;
  final String? email;
  final List<String> links;
  final List<String> languages;
  final String? massScheduleNote;
  final List<Adoration> adorations;
  final bool? hasConfession;
  final List<Community> communities;
  final double? lat;
  final double? lon;
  final List<String> photos;
  final DateTime? updatedAt;

  /// When an API response last wrote this row. Null while the row comes from
  /// the one-time bootstrap import only.
  final DateTime? localSyncedAt;

  /// No API field corresponds to this, so it survives from the bootstrap
  /// import and an API response never overwrites it.
  final bool? isGreek;

  ChurchDetails({
    required this.id,
    required this.name,
    required this.commonName,
    required this.names,
    required this.alternativeNames,
    required this.country,
    required this.diocese,
    required this.county,
    required this.city,
    required this.street,
    required this.gettingThere,
    required this.parish,
    required this.description,
    required this.accessibility,
    required this.email,
    required this.links,
    required this.languages,
    required this.massScheduleNote,
    required this.adorations,
    required this.hasConfession,
    required this.communities,
    required this.lat,
    required this.lon,
    required this.photos,
    required this.updatedAt,
    required this.localSyncedAt,
    required this.isGreek,
  });
}
