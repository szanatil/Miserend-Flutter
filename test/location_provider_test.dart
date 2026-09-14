import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:miserend/location_provider.dart';

Position _fixAt(DateTime timestamp) => Position(
      latitude: 47.4979,
      longitude: 19.0402,
      timestamp: timestamp,
      accuracy: 10,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  group('isRecentEnough', () {
    final now = DateTime(2026, 9, 14, 14, 0);
    const fiveMinutes = Duration(minutes: 5);

    test('a fix from 4 minutes ago is used as it is', () {
      final fix = _fixAt(now.subtract(const Duration(minutes: 4)));

      expect(LocationProvider.isRecentEnough(fix, now, fiveMinutes), isTrue);
    });

    test('a fix exactly 5 minutes old is still used', () {
      final fix = _fixAt(now.subtract(fiveMinutes));

      expect(LocationProvider.isRecentEnough(fix, now, fiveMinutes), isTrue);
    });

    test('a fix older than 5 minutes asks for a fresh one', () {
      final fix = _fixAt(now.subtract(const Duration(minutes: 5, seconds: 1)));

      expect(LocationProvider.isRecentEnough(fix, now, fiveMinutes), isFalse);
    });

    test('no last known fix asks for a fresh one', () {
      expect(LocationProvider.isRecentEnough(null, now, fiveMinutes), isFalse);
    });
  });
}
