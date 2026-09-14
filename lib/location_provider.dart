import 'dart:async';

import 'package:geolocator/geolocator.dart';

class LocationProvider {
  /// The device position. By default the last known position is taken at any
  /// age, and a fresh fix is only asked for when there is none.
  ///
  /// A caller that must not work from an old position — one taken in another
  /// town, say — passes [maxLastKnownAge]: an older last known position is
  /// then ignored, and the fresh fix gives up after [freshFixTimeout] with a
  /// [TimeoutException]. The other callers keep the old behaviour, because a
  /// fresh fix can take long enough to make the map or the church list slower.
  static Future<Position> getPosition({
    Duration? maxLastKnownAge,
    Duration? freshFixTimeout,
  }) async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    var lastKnown = await Geolocator.getLastKnownPosition(forceAndroidLocationManager: true);
    if (lastKnown != null &&
        (maxLastKnownAge == null ||
            isRecentEnough(lastKnown, DateTime.now(), maxLastKnownAge))) {
      return lastKnown;
    }
    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    final fresh = Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        forceAndroidLocationManager: true);
    return freshFixTimeout == null
        ? await fresh
        : await fresh.timeout(freshFixTimeout);
  }

  /// Whether [lastKnown] is no older than [maxAge] at [now].
  static bool isRecentEnough(
      Position? lastKnown, DateTime now, Duration maxAge) {
    if (lastKnown == null) return false;
    return now.difference(lastKnown.timestamp) <= maxAge;
  }
}
