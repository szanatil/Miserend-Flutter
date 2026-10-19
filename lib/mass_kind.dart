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

/// The miserend.hu's four groups, one of which every occasion belongs to
/// (CONTEXT.md, „Alkalom kategóriája"): the values of the `search` endpoint's
/// `categories`, `MASS`, `ADORATION`, `CONFESSION` and `OTHER`.
enum OccasionCategory { mass, adoration, confession, other }

/// The kinds that make an occasion adoration or confession; any other kind
/// that is not a mass, an unknown one too, is another prayer.
const String _adoration = 'Szentségimádás';
const String _confession = 'Gyóntatás';

/// Which category a cached row's occasion belongs to, decided by its kind.
/// A mass is what [isMass] says it is, so that searching for masses alone
/// finds what it always did.
OccasionCategory occasionCategory(CachedMass row) {
  if (isMass(row)) return OccasionCategory.mass;
  final text = row.info;
  if (text == null) return OccasionCategory.other;
  final kind = _withoutDenomination(text);
  if (_restAfterKind(kind, _adoration) != null) {
    return OccasionCategory.adoration;
  }
  if (_restAfterKind(kind, _confession) != null) {
    return OccasionCategory.confession;
  }
  return OccasionCategory.other;
}

/// The denominations a list answer puts in front of the event's kind.
const List<String> _denominations = ['Római katolikus ', 'Görögkatolikus '];

/// What may follow the kind in a list answer's `informacio`: a comma or, as
/// live answers show, a space or a parenthesis.
const List<String> _afterKind = [',', ' ', '('];

/// [info] trimmed, with the denomination in front of its kind left out.
String _withoutDenomination(String info) {
  final text = info.trim();
  for (final denomination in _denominations) {
    if (text.startsWith(denomination)) {
      return text.substring(denomination.length);
    }
  }
  return text;
}

/// What follows [kind] at the start of [text]; null when [text] does not
/// start with that kind — "Szentmisék" is no "Szentmise".
String? _restAfterKind(String text, String kind) {
  if (!text.startsWith(kind)) return null;
  final rest = text.substring(kind.length);
  return rest.isEmpty || _afterKind.any(rest.startsWith) ? rest : null;
}

/// A list answer's `informacio` — "Római katolikus Szentmise, Csendes" — read
/// as a mass: its [title] among [massTitles], and the mass detail after it
/// (CONTEXT.md, „Mise jellemzője"), as the data stewards wrote it: "Csendes",
/// "latin nyelven", "(adventben 6:00)". Null when it describes no mass.
///
/// The denomination is left out of both: nearly every mass is Roman Catholic,
/// and the card shows the Greek Catholic one by its title.
({String title, String? detail})? describeMass(String? info) {
  if (info == null) return null;
  final text = _withoutDenomination(info);
  for (final title in massTitles) {
    final rest = _restAfterKind(text, title);
    if (rest == null) continue;
    final detail = rest.replaceFirst(RegExp(r'^[,\s]+'), '');
    return (title: title, detail: detail.isEmpty ? null : detail);
  }
  return null;
}
