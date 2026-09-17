import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/mass_detail.dart';

/// A part as a plain value to compare: the type, or the text.
Object _plain(MassDetailPart part) => switch (part) {
  MassTypePart(:final type) => type,
  MassDetailText(:final text) => text,
};

void main() {
  // The detail is what [describeMass] leaves after the kind; miserend.hu
  // builds it as "[language nyelven][, type, type][ (comment)]".
  const split = <String, List<Object>>{
    'Csendes': [MassType.silent],
    'Orgonás': [MassType.organ],
    'Gitáros, Diák': [MassType.guitar, MassType.student],
    'Családos/mocorgós, Egyetemista/ifjúsági, Énekes': [
      MassType.family,
      MassType.universityYouth,
      MassType.singer,
    ],
    'Csendes (Mária-kápolnában)': [MassType.silent, '(Mária-kápolnában)'],
    'latin nyelven': ['latin nyelven'],
    'latin nyelven, Csendes': ['latin nyelven', MassType.silent],
    '(adventben 6:00)': ['(adventben 6:00)'],
    '(A szentmise után szentségimádás, kompletórium.)': [
      '(A szentmise után szentségimádás, kompletórium.)',
    ],
    'Csendes (gitáros, Csendes)': [MassType.silent, '(gitáros, Csendes)'],
    'Csendes, Ismeretlen': [MassType.silent, 'Ismeretlen'],
  };

  for (final MapEntry(key: detail, value: parts) in split.entries) {
    test('"$detail" splits into $parts', () {
      expect(massDetailParts(detail).map(_plain).toList(), parts);
    });
  }

  test('every type is labelled as miserend.hu writes it', () {
    expect(
      {for (final type in MassType.values) type: type.label},
      {
        MassType.family: 'Családos/mocorgós',
        MassType.student: 'Diák',
        MassType.universityYouth: 'Egyetemista/ifjúsági',
        MassType.guitar: 'Gitáros',
        MassType.organ: 'Orgonás',
        MassType.silent: 'Csendes',
        MassType.singer: 'Énekes',
      },
    );
  });
}
