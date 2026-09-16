import 'package:latlong2/latlong.dart';
import 'package:miserend/database/cache/church_location.dart';

/// The step the distance is rounded to: neither the position nor a church's
/// coordinates are more exact than this, and the NearBy API's `distance_km`
/// comes at the same resolution (CONTEXT.md, „Légvonal-távolság").
const int _roundingMeters = 10;

/// From this many metres on the distance is written in kilometres; below it
/// in metres, where a „0,3 km" would read worse than „300 m".
const int _kilometreThresholdMeters = 1000;

const Distance _haversine = DistanceHaversine(roundResult: false);

/// The straight-line distance from [position] to a church at ([lat], [lon]) in
/// kilometres (CONTEXT.md, „Légvonal-távolság"). Null where it is not known:
/// no position, or a church without real coordinates — never a zero.
double? straightLineKm(LatLng? position, double? lat, double? lon) {
  if (position == null || !ChurchLocation.isKnown(lat, lon)) return null;
  return _haversine.as(LengthUnit.Kilometer, position, LatLng(lat!, lon!));
}

/// „300 m", „1 km", „1,2 km": rounded to [_roundingMeters] first, then metres
/// below [_kilometreThresholdMeters] and kilometres with one decimal, the „,0"
/// left off, from there (spec 0007, „Számítás és formátum").
String formatDistance(double km) {
  final meters = (km * 1000 / _roundingMeters).round() * _roundingMeters;
  if (meters < _kilometreThresholdMeters) return '$meters m';

  // Whole hundreds of metres, so that no floating-point edge of
  // toStringAsFixed can move the decimal.
  final hundreds = (meters + 50) ~/ 100;
  final whole = hundreds ~/ 10;
  final tenth = hundreds % 10;
  return tenth == 0 ? '$whole km' : '$whole,$tenth km';
}
