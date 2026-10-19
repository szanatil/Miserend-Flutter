import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/database/cache/cached_mass.dart';
import 'package:miserend/mass_kind.dart';

CachedMass _row(MassSource source, String? info) => CachedMass(
  id: null,
  apiMassId: null,
  churchId: 38,
  time: DateTime(2026, 9, 15, 18, 0),
  info: info,
  source: source,
);

void main() {
  group('a bootstrap row', () {
    test('is always a mass, whatever its note says', () {
      expect(isMass(_row(MassSource.bootstrap, 'gitáros')), isTrue);
      expect(isMass(_row(MassSource.bootstrap, null)), isTrue);
    });
  });

  group('a NearbyMasses row', () {
    for (final title in [
      'Szentmise',
      'Szent Liturgia',
      'Régi rítusú szentmise',
    ]) {
      test('"$title" is a mass', () {
        expect(isMass(_row(MassSource.nearbyMasses, title)), isTrue);
      });
    }

    for (final title in [
      'Gyóntatás',
      'Vecsernye',
      'Szentségimádás',
      'Ismeretlen',
    ]) {
      test('"$title" is not a mass', () {
        expect(isMass(_row(MassSource.nearbyMasses, title)), isFalse);
      });
    }

    test('a row with no title is not a mass', () {
      expect(isMass(_row(MassSource.nearbyMasses, null)), isFalse);
    });
  });

  group('a list answer row', () {
    // Every kind seen in the live NearBy answer for central Budapest and the
    // Budapest search, 2026-09-15.
    const masses = [
      'Római katolikus Szentmise',
      'Római katolikus Szentmise, Csendes',
      'Római katolikus Szentmise, Csendes (Mária-kápolnában)',
      'Római katolikus Szentmise latin nyelven',
      'Római katolikus Szentmise (adventben 6:00)',
      'Görögkatolikus Szent Liturgia',
    ];
    const others = [
      'Római katolikus Gyóntatás',
      'Római katolikus Gyóntatás ukrán nyelven',
      'Római katolikus Szentségimádás',
      'Római katolikus Szentségimádás, Csendes',
      'Görögkatolikus Szentségimádás',
      'Római katolikus Igeliturgia',
      'Római katolikus Litánia (Szent Antal litánia)',
      'Római katolikus Zsolozsma (Laudes)',
      'Római katolikus Ismeretlen esemény',
    ];

    for (final info in masses) {
      test('"$info" is a mass', () {
        expect(isMass(_row(MassSource.dailyList, info)), isTrue);
      });
    }

    for (final info in others) {
      test('"$info" is not a mass', () {
        expect(isMass(_row(MassSource.dailyList, info)), isFalse);
      });
    }

    test('a row with no text is not a mass', () {
      expect(isMass(_row(MassSource.dailyList, null)), isFalse);
    });
  });

  group('the occasion category', () {
    test('of a bootstrap row is always mass', () {
      expect(
        occasionCategory(_row(MassSource.bootstrap, 'Szentségimádás')),
        OccasionCategory.mass,
      );
    });

    const nearby = {
      'Szentmise': OccasionCategory.mass,
      'Szent Liturgia': OccasionCategory.mass,
      'Régi rítusú szentmise': OccasionCategory.mass,
      'Szentségimádás': OccasionCategory.adoration,
      'Görögkatolikus Szentségimádás': OccasionCategory.adoration,
      'Gyóntatás': OccasionCategory.confession,
      'Vecsernye': OccasionCategory.other,
      'Rózsafüzér ima': OccasionCategory.other,
      'Ismeretlen': OccasionCategory.other,
      null: OccasionCategory.other,
    };
    for (final MapEntry(key: title, value: category) in nearby.entries) {
      test('of the NearbyMasses row "$title" is ${category.name}', () {
        expect(
          occasionCategory(_row(MassSource.nearbyMasses, title)),
          category,
        );
      });
    }

    const listed = {
      'Római katolikus Szentmise, Csendes': OccasionCategory.mass,
      'Görögkatolikus Szent Liturgia': OccasionCategory.mass,
      'Római katolikus Szentségimádás': OccasionCategory.adoration,
      'Római katolikus Szentségimádás, Csendes': OccasionCategory.adoration,
      'Görögkatolikus Szentségimádás': OccasionCategory.adoration,
      'Római katolikus Gyóntatás ukrán nyelven': OccasionCategory.confession,
      'Római katolikus Gyóntatás': OccasionCategory.confession,
      'Római katolikus Zsolozsma (Laudes)': OccasionCategory.other,
      'Görögkatolikus Vecsernye': OccasionCategory.other,
      'Római katolikus Szentségimádások': OccasionCategory.other,
      'Római katolikus Ismeretlen esemény': OccasionCategory.other,
      null: OccasionCategory.other,
    };
    for (final MapEntry(key: info, value: category) in listed.entries) {
      test('of the list answer row "$info" is ${category.name}', () {
        expect(occasionCategory(_row(MassSource.dailyList, info)), category);
      });
    }
  });

  group('a mass description', () {
    // Live descriptions from the Church answer for central Budapest,
    // 2026-09-17.
    const described = {
      'Római katolikus Szentmise': ('Szentmise', null),
      'Római katolikus Szentmise, Csendes': ('Szentmise', 'Csendes'),
      'Római katolikus Szentmise, Csendes (Mária-kápolnában)': (
        'Szentmise',
        'Csendes (Mária-kápolnában)',
      ),
      'Római katolikus Szentmise latin nyelven': ('Szentmise', 'latin nyelven'),
      'Római katolikus Szentmise (adventben 6:00)': (
        'Szentmise',
        '(adventben 6:00)',
      ),
      'Görögkatolikus Szent Liturgia': ('Szent Liturgia', null),
      'Görögkatolikus Szent Liturgia, Csendes': ('Szent Liturgia', 'Csendes'),
      'Római katolikus Régi rítusú szentmise': ('Régi rítusú szentmise', null),
    };

    for (final MapEntry(key: info, value: (title, detail))
        in described.entries) {
      test('"$info" is a $title with ${detail ?? 'no detail'}', () {
        final description = describeMass(info);

        expect(description?.title, title);
        expect(description?.detail, detail);
      });
    }

    for (final info in [
      'Római katolikus Gyóntatás tagalog/filippínó nyelven',
      'Római katolikus Szentségimádás, Csendes',
      'Római katolikus Szentmisék',
      null,
    ]) {
      test('"$info" describes no mass', () {
        expect(describeMass(info), isNull);
      });
    }
  });
}
