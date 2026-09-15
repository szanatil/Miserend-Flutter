import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Why there is no position (CONTEXT.md, „Helyzet nem elérhető"). The user has
/// to do something different about each.
enum PositionUnavailableReason {
  /// The app may ask again.
  permissionDenied,

  /// Only the phone's settings can grant it now.
  permissionDeniedForever,

  /// Location services are switched off in the phone's settings.
  serviceDisabled,

  /// No recent last known position, and no fresh fix within the timeout.
  noFreshFix,
}

sealed class PositionResult {
  const PositionResult();
}

final class PositionFound extends PositionResult {
  const PositionFound(this.position);

  final Position position;
}

final class PositionUnavailable extends PositionResult {
  const PositionUnavailable(this.reason);

  final PositionUnavailableReason reason;
}

/// The user's position (CONTEXT.md, „Helyzet"), by the same rule for every
/// screen that needs it.
class LocationProvider {
  /// A last known position older than this may come from another town.
  static const Duration maxPositionAge = Duration(minutes: 5);

  /// How long to wait for a fresh fix before giving up.
  static const Duration fixTimeout = Duration(seconds: 15);

  LocationProvider({GeolocatorPlatform? platform, this.clock = DateTime.now})
      : _platform = platform;

  final GeolocatorPlatform? _platform;
  final DateTime Function() clock;

  /// Read late, so that the plugin's registered instance is the one used.
  GeolocatorPlatform get _geolocator => _platform ?? GeolocatorPlatform.instance;

  /// A last known position no older than [maxPositionAge], otherwise a fresh
  /// fix within [fixTimeout]. Asks for the permission once more when it has
  /// been denied but may still be asked for.
  Future<PositionResult> currentPosition() async {
    try {
      if (!await _geolocator.isLocationServiceEnabled()) {
        return const PositionUnavailable(
            PositionUnavailableReason.serviceDisabled);
      }

      var permission = await _geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await _geolocator.requestPermission();
      }
      switch (permission) {
        case LocationPermission.denied:
          return const PositionUnavailable(
              PositionUnavailableReason.permissionDenied);
        case LocationPermission.deniedForever:
          return const PositionUnavailable(
              PositionUnavailableReason.permissionDeniedForever);
        case LocationPermission.whileInUse:
        case LocationPermission.always:
        case LocationPermission.unableToDetermine:
          break;
      }

      final lastKnown = await _geolocator.getLastKnownPosition(
          forceLocationManager: _onAndroid);
      if (isRecentEnough(lastKnown, clock(), maxPositionAge)) {
        return PositionFound(lastKnown!);
      }

      final fresh = await _geolocator
          .getCurrentPosition(locationSettings: _settings())
          .timeout(fixTimeout);
      return PositionFound(fresh);
    } on LocationServiceDisabledException {
      return const PositionUnavailable(
          PositionUnavailableReason.serviceDisabled);
    } on PermissionDeniedException {
      return const PositionUnavailable(
          PositionUnavailableReason.permissionDenied);
    } catch (_) {
      // A timeout, or anything else that kept the fix from arriving, is
      // something a retry may get past.
      return const PositionUnavailable(PositionUnavailableReason.noFreshFix);
    }
  }

  Future<void> openAppSettings() => _geolocator.openAppSettings();

  Future<void> openLocationSettings() => _geolocator.openLocationSettings();

  static bool get _onAndroid => defaultTargetPlatform == TargetPlatform.android;

  static LocationSettings _settings() => _onAndroid
      ? AndroidSettings(
          accuracy: LocationAccuracy.best, forceLocationManager: true)
      : const LocationSettings(accuracy: LocationAccuracy.best);

  /// Whether [lastKnown] is no older than [maxAge] at [now].
  static bool isRecentEnough(
      Position? lastKnown, DateTime now, Duration maxAge) {
    if (lastKnown == null) return false;
    return now.difference(lastKnown.timestamp) <= maxAge;
  }
}
