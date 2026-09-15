import 'package:miserend/database/cache/cached_mass.dart';

/// The titles that count as a mass (CONTEXT.md, „Mise vs. egyéb liturgikus
/// esemény"). Everything else the API returns — and any title nobody has
/// listed yet — is left out.
const Set<String> massTitles = {
  'Szentmise',
  'Szent Liturgia',
  'Régi rítusú szentmise',
};

/// Whether a cached row is a mass. What its [CachedMass.info] means depends on
/// where the row came from, so the rule does too.
bool isMass(CachedMass row) {
  switch (row.source) {
    case MassSource.bootstrap:
      // The export only holds masses; its note is a remark such as "gitáros".
      return true;
    case MassSource.nearbyMasses:
      return massTitles.contains(row.info);
  }
}
