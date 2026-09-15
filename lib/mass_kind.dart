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
    case MassSource.dailyList:
      return _isMassDescription(row.info);
  }
}

/// The denominations a list answer puts in front of the event's kind.
const List<String> _denominations = ['Római katolikus ', 'Görögkatolikus '];

/// Whether a list answer's `informacio` — "Római katolikus Szentmise,
/// Csendes" — describes a mass. The kind sits after the denomination and
/// before the details, which follow a comma or, as live answers show, a
/// space or a parenthesis: "Szentmise latin nyelven", "Szentmise (adventben
/// 6:00)".
bool _isMassDescription(String? info) {
  if (info == null) return false;
  var kind = info.split(',').first.trim();
  for (final denomination in _denominations) {
    if (kind.startsWith(denomination)) {
      kind = kind.substring(denomination.length);
      break;
    }
  }
  return massTitles.any(
    (title) =>
        kind == title ||
        kind.startsWith('$title ') ||
        kind.startsWith('$title('),
  );
}
