import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miserend/straight_line_distance.dart';

void main() {
  group('formatDistance', () {
    const cases = [
      (0.0, '0 m'),
      (0.296, '300 m'),
      (0.994, '990 m'),
      (0.995, '1 km'),
      (1.23, '1,2 km'),
      (1.25, '1,3 km'),
      (12.0, '12 km'),
      (12.46, '12,5 km'),
      (12.96, '13 km'),
    ];
    for (final (km, text) in cases) {
      test('writes $km km as „$text"', () {
        expect(formatDistance(km), text);
      });
    }
  });

  group('straightLineKm', () {
    const budapest = LatLng(47.4979, 19.0402);

    test('measures the distance along the surface', () {
      // Budapest to Kecskemét is about 80 km as the crow flies.
      final km = straightLineKm(budapest, 46.9062, 19.6913)!;
      expect(km, closeTo(80, 5));
    });

    test('is unknown without a position', () {
      expect(straightLineKm(null, 46.9062, 19.6913), isNull);
    });

    for (final (lat, lon) in [(null, 19.0), (47.0, null), (0.0, 0.0)]) {
      test('is unknown for a church at ($lat, $lon)', () {
        expect(straightLineKm(budapest, lat, lon), isNull);
      });
    }
  });
}
