/// The types a mass may have on miserend.hu, the one part of a mass detail
/// (CONTEXT.md, „Mise jellemzője") that comes from a closed set: the data
/// stewards pick them from a list, and the API writes each by the label below
/// (miserend.hu `webapp/i18n/hu.json`). The card draws them as icons.
enum MassType {
  family('Családos/mocorgós', 'assets/types/family.png'),
  student('Diák', 'assets/types/student.png'),
  universityYouth('Egyetemista/ifjúsági', 'assets/types/university_youth.png'),
  guitar('Gitáros', 'assets/types/guitar.png'),
  organ('Orgonás', 'assets/types/organ.png'),
  silent('Csendes', 'assets/types/silent.png'),
  singer('Énekes', 'assets/types/singer.png');

  const MassType(this.label, this.iconAsset);

  /// The word the API writes, and the one shown on tapping the icon.
  final String label;
  final String iconAsset;
}

/// One part of a mass detail, in the order the detail holds them.
sealed class MassDetailPart {
  const MassDetailPart();

  /// The part as it reads: a type's word, or the text as written.
  String get label => switch (this) {
    MassTypePart(:final type) => type.label,
    MassDetailText(:final text) => text,
  };

  /// A type's icon; the other parts have none.
  String? get iconAsset => switch (this) {
    MassTypePart(:final type) => type.iconAsset,
    MassDetailText() => null,
  };
}

/// A type from [MassType]'s closed set.
final class MassTypePart extends MassDetailPart {
  const MassTypePart(this.type);

  final MassType type;
}

/// Anything else, as written: the language ("latin nyelven"), the steward's
/// comment ("(adventben 6:00)"), or a type the app does not know yet.
final class MassDetailText extends MassDetailPart {
  const MassDetailText(this.text);

  final String text;
}

/// A mass detail split into its parts. miserend.hu builds the detail as
/// "[language nyelven][, type, type][ (comment)]", so the comment starts at
/// the first parenthesis — neither a language nor a type holds one — and is
/// left whole, commas and type words included; before it, each
/// comma-separated segment is a type or text.
List<MassDetailPart> massDetailParts(String detail) {
  final commentStart = detail.indexOf('(');
  final head = commentStart < 0 ? detail : detail.substring(0, commentStart);
  final comment = commentStart < 0 ? '' : detail.substring(commentStart).trim();
  return [
    for (final segment in head.split(','))
      if (segment.trim() case final text when text.isNotEmpty)
        switch (_typeLabelled(text)) {
          final type? => MassTypePart(type),
          null => MassDetailText(text),
        },
    if (comment.isNotEmpty) MassDetailText(comment),
  ];
}

MassType? _typeLabelled(String text) {
  for (final type in MassType.values) {
    if (type.label == text) return type;
  }
  return null;
}
