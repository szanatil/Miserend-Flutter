import 'dart:async';

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

/// The device, as the geolocator plugin reports it.
class _FakeGeolocator extends GeolocatorPlatform {
  _FakeGeolocator({
    this.serviceEnabled = true,
    this.permission = LocationPermission.whileInUse,
    LocationPermission? afterRequest,
    this.lastKnown,
    this.fresh,
  }) : afterRequest = afterRequest ?? permission;

  bool serviceEnabled;
  LocationPermission permission;
  LocationPermission afterRequest;
  Position? lastKnown;

  /// Null means the fix never arrives.
  Position? fresh;

  int permissionRequests = 0;
  int freshFixRequests = 0;
  int appSettingsOpened = 0;
  int locationSettingsOpened = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    return permission = afterRequest;
  }

  @override
  Future<Position?> getLastKnownPosition(
          {bool forceLocationManager = false}) async =>
      lastKnown;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    freshFixRequests++;
    final fix = fresh;
    return fix == null ? Completer<Position>().future : Future.value(fix);
  }

  @override
  Future<bool> openAppSettings() async {
    appSettingsOpened++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    locationSettingsOpened++;
    return true;
  }
}

void main() {
  final now = DateTime(2026, 9, 14, 14, 0);

  LocationProvider providerFor(_FakeGeolocator device) =>
      LocationProvider(platform: device, clock: () => now);

  PositionUnavailableReason? reasonOf(PositionResult result) =>
      switch (result) {
        PositionFound() => null,
        PositionUnavailable(:final reason) => reason,
      };

  group('position unavailable', () {
    test('location services switched off', () async {
      final device = _FakeGeolocator(serviceEnabled: false);

      final result = await providerFor(device).currentPosition();

      expect(reasonOf(result), PositionUnavailableReason.serviceDisabled);
    });

    test('permission denied, after asking for it once more', () async {
      final device = _FakeGeolocator(permission: LocationPermission.denied);

      final result = await providerFor(device).currentPosition();

      expect(reasonOf(result), PositionUnavailableReason.permissionDenied);
      expect(device.permissionRequests, 1);
    });

    test('permission denied for good, which cannot be asked for again',
        () async {
      final device =
          _FakeGeolocator(permission: LocationPermission.deniedForever);

      final result = await providerFor(device).currentPosition();

      expect(
          reasonOf(result), PositionUnavailableReason.permissionDeniedForever);
      expect(device.permissionRequests, 0);
    });

    test('asking again can turn into denied for good', () async {
      final device = _FakeGeolocator(
        permission: LocationPermission.denied,
        afterRequest: LocationPermission.deniedForever,
      );

      final result = await providerFor(device).currentPosition();

      expect(
          reasonOf(result), PositionUnavailableReason.permissionDeniedForever);
    });

    testWidgets('no fresh fix in time', (tester) async {
      // testWidgets runs on a fake clock, so the wait costs nothing.
      final device = _FakeGeolocator(fresh: null);

      PositionResult? result;
      providerFor(device).currentPosition().then((value) => result = value);
      await tester.pump(LocationProvider.fixTimeout - const Duration(seconds: 1));
      expect(result, isNull);

      await tester.pump(const Duration(seconds: 1));
      expect(reasonOf(result!), PositionUnavailableReason.noFreshFix);
    });
  });

  group('position found', () {
    test('a permission granted on asking gives a position', () async {
      final fix = _fixAt(now);
      final device = _FakeGeolocator(
        permission: LocationPermission.denied,
        afterRequest: LocationPermission.whileInUse,
        fresh: fix,
      );

      final result = await providerFor(device).currentPosition();

      expect((result as PositionFound).position, fix);
    });

    test('a last known fix from 5 minutes ago is used as it is', () async {
      final fix = _fixAt(now.subtract(const Duration(minutes: 5)));
      final device = _FakeGeolocator(lastKnown: fix, fresh: _fixAt(now));

      final result = await providerFor(device).currentPosition();

      expect((result as PositionFound).position, fix);
      expect(device.freshFixRequests, 0);
    });

    test('a last known fix older than 5 minutes is not a position', () async {
      final old = _fixAt(now.subtract(const Duration(minutes: 5, seconds: 1)));
      final fresh = _fixAt(now);
      final device = _FakeGeolocator(lastKnown: old, fresh: fresh);

      final result = await providerFor(device).currentPosition();

      expect((result as PositionFound).position, fresh);
      expect(device.freshFixRequests, 1);
    });
  });

  group('settings', () {
    test('open the app settings and the location settings', () async {
      final device = _FakeGeolocator();
      final provider = providerFor(device);

      await provider.openAppSettings();
      await provider.openLocationSettings();

      expect(device.appSettingsOpened, 1);
      expect(device.locationSettingsOpened, 1);
    });
  });
}
