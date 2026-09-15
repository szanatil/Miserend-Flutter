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
    for (final title in ['Szentmise', 'Szent Liturgia', 'Régi rítusú szentmise']) {
      test('"$title" is a mass', () {
        expect(isMass(_row(MassSource.nearbyMasses, title)), isTrue);
      });
    }

    for (final title in ['Gyóntatás', 'Vecsernye', 'Szentségimádás', 'Ismeretlen']) {
      test('"$title" is not a mass', () {
        expect(isMass(_row(MassSource.nearbyMasses, title)), isFalse);
      });
    }

    test('a row with no title is not a mass', () {
      expect(isMass(_row(MassSource.nearbyMasses, null)), isFalse);
    });
  });
}
