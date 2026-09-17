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
      return describeMass(row.info) != null;
  }
}

/// The denominations a list answer puts in front of the event's kind.
const List<String> _denominations = ['Római katolikus ', 'Görögkatolikus '];

/// What may follow the kind in a list answer's `informacio`: a comma or, as
/// live answers show, a space or a parenthesis.
const List<String> _afterKind = [',', ' ', '('];

/// A list answer's `informacio` — "Római katolikus Szentmise, Csendes" — read
/// as a mass: its [title] among [massTitles], and the mass detail after it
/// (CONTEXT.md, „Mise jellemzője"), as the data stewards wrote it: "Csendes",
/// "latin nyelven", "(adventben 6:00)". Null when it describes no mass.
///
/// The denomination is left out of both: nearly every mass is Roman Catholic,
/// and the card shows the Greek Catholic one by its title.
({String title, String? detail})? describeMass(String? info) {
  if (info == null) return null;
  var text = info.trim();
  for (final denomination in _denominations) {
    if (text.startsWith(denomination)) {
      text = text.substring(denomination.length);
      break;
    }
  }
  for (final title in massTitles) {
    if (!text.startsWith(title)) continue;
    final rest = text.substring(title.length);
    if (rest.isNotEmpty && !_afterKind.any(rest.startsWith)) continue;
    final detail = rest.replaceFirst(RegExp(r'^[,\s]+'), '');
    return (title: title, detail: detail.isEmpty ? null : detail);
  }
  return null;
}
