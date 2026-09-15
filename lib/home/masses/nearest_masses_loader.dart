import 'package:geolocator/geolocator.dart';
import 'package:miserend/api/api_result.dart';
import 'package:miserend/api/miserend_api_client.dart';
import 'package:miserend/api/nearby_masses_item.dart';
import 'package:miserend/database/cache/cache_database.dart';
import 'package:miserend/home/masses/nearest_masses.dart';
import 'package:miserend/location_provider.dart';

/// The position could not be determined, for [reason].
class LocationUnavailable implements Exception {
  const LocationUnavailable(this.reason);

  final PositionUnavailableReason reason;
}

/// The API could not be asked: offline, an HTTP error, or an error flag in the
/// response.
class MassesUnavailable implements Exception {
  const MassesUnavailable();
}

/// Supplies the Misék tab: the raw `NearbyMasses` response for the user's
/// position, and each church's thumbnail from the cache. It lives outside the
/// page so that the page can be pumped against a fake.
class NearestMassesLoader {
  NearestMassesLoader({
    MiserendApiClient? api,
    CacheDatabase? cache,
    LocationProvider? location,
  }) : _api = api ?? MiserendApiClient(),
       _cache = cache,
       _location = location ?? LocationProvider();

  final MiserendApiClient _api;
  final LocationProvider _location;
  CacheDatabase? _cache;
  final Map<int, Future<String?>> _thumbnails = {};

  /// Every item around the user that can still be reachable at [now], masses
  /// or not; [selectNearestMasses] picks the list from it. Throws
  /// [LocationUnavailable] or [MassesUnavailable]. Nothing falls back on the
  /// cache or on the legacy export: the list promises masses one can still get
  /// to, and a stale one is worse than saying it could not be loaded.
  Future<List<NearbyMassesItem>> fetch(DateTime now) async {
    final Position position;
    switch (await _location.currentPosition()) {
      case PositionFound(position: final found):
        position = found;
      case PositionUnavailable(:final reason):
        throw LocationUnavailable(reason);
    }

    final result = await _api.fetchNearbyMasses(
      lat: position.latitude,
      lon: position.longitude,
      from: reachableFrom(now),
      until: nearestMassesUntil(now),
    );
    return switch (result) {
      ApiSuccess(:final value) => value,
      ApiFailed() => throw const MassesUnavailable(),
    };
  }

  /// The church's first cached photo, or null. The API item carries no image.
  /// The same future is handed back for a church every time, so a row that
  /// rebuilds does not read the cache again.
  Future<String?> thumbnailUrl(int churchId) {
    return _thumbnails[churchId] ??= _readThumbnail(churchId);
  }

  Future<String?> _readThumbnail(int churchId) async {
    try {
      final cache = _cache ??= await CacheDatabase.create();
      final church = await cache.getChurch(churchId);
      final photos = church?.photos ?? const <String>[];
      return photos.isEmpty ? null : photos.first;
    } catch (_) {
      return null;
    }
  }
}
