import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:miserend/api/nearby_masses_item.dart';
import 'package:miserend/database/cache/adoration.dart';
import 'package:miserend/database/cache/cached_mass.dart';
import 'package:miserend/database/cache/church_details.dart';
import 'package:miserend/database/cache/community.dart';

/// Reads the miserend.hu v4 JSON API. Every failure — offline, HTTP error,
/// error flag in the payload — is reported as a null/empty result, because
/// most callers fall back on the cache and show no error of their own.
/// [fetchNearbyMasses] is the exception: see there.
class MiserendApiClient {
  static const String baseUrl = 'https://miserend.hu';

  /// The API refuses a larger limit. A church busy enough to hold more than
  /// this many masses in the requested range loses the tail of its schedule.
  static const int _massLimit = 100;

  /// Narrow enough that, in practice, only the church itself falls inside it.
  /// The v4 API has no endpoint for one church's schedule over several days,
  /// so it is derived from the nearby-masses search instead.
  static const double _selfRadiusKm = 0.1;

  /// The widest radius the API accepts. The response comes back nearest
  /// first, so the limit, not the radius, is what bounds it in practice.
  static const int _nearbyRadiusKm = 200;

  final http.Client _client;

  MiserendApiClient({http.Client? client}) : _client = client ?? http.Client();

  Future<ChurchDetails?> fetchChurch(int id) async {
    final body = await _post('church', {'id': id, 'response_length': 'full'});
    if (body == null) return null;
    return _churchFromJson(body);
  }

  /// The masses [churchId] holds between [from] and [until]. The response can
  /// carry a second church that shares the coordinates, so it is filtered by
  /// church id here as well.
  Future<List<CachedMass>> fetchMassesForChurch({
    required int churchId,
    required double lat,
    required double lon,
    required DateTime from,
    required DateTime until,
  }) async {
    final body = await _post('nearbymasses', {
      'lat': lat,
      'lon': lon,
      'radius': _selfRadiusKm,
      'from': _formatDate(from),
      'until': _formatDate(until),
      'limit': _massLimit,
    });
    if (body == null) return const <CachedMass>[];

    final masses = body['misek'];
    if (masses is! List) return const <CachedMass>[];

    final occurrences = <CachedMass>[];
    for (final item in masses.whereType<Map>()) {
      if (_churchIdOf(item) != churchId) continue;
      final time = parseApiDateTime(_text(item['start_date']));
      if (time == null) continue;
      occurrences.add(CachedMass(
        id: null,
        apiMassId: item['id'] as int?,
        churchId: churchId,
        time: time,
        info: _text(item['title']),
      ));
    }
    return occurrences;
  }

  /// Everything the API holds within [_nearbyRadiusKm] of the position,
  /// starting between [from] and [until], nearest first — masses and other
  /// liturgical events alike.
  ///
  /// Unlike the other calls, a failure is null rather than an empty list: the
  /// nearest masses have no cache to fall back on, and "no mass nearby" and
  /// "could not ask" need different messages.
  Future<List<NearbyMassesItem>?> fetchNearbyMasses({
    required double lat,
    required double lon,
    required DateTime from,
    required DateTime until,
  }) async {
    final body = await _post('nearbymasses', {
      'lat': lat,
      'lon': lon,
      'radius': _nearbyRadiusKm,
      'from': _formatDateTime(from),
      'until': _formatDateTime(until),
      'limit': _massLimit,
    });
    if (body == null) return null;

    final items = body['misek'];
    if (items is! List) return null;

    final parsed = <NearbyMassesItem>[];
    for (final item in items.whereType<Map>()) {
      final church = item['church'];
      if (church is! Map || church['id'] is! int) continue;
      final start = parseApiDateTime(_text(item['start_date']));
      final distance = _number(item['distance_km']);
      if (start == null || distance == null) continue;
      parsed.add(NearbyMassesItem(
        churchId: church['id'] as int,
        churchName: _text(church['name']),
        city: _text(church['city']),
        lat: _number(church['lat']),
        lon: _number(church['lon']),
        distanceKm: distance,
        start: start,
        title: _text(item['title']),
      ));
    }
    return parsed;
  }

  int? _churchIdOf(Map item) {
    final church = item['church'];
    return church is Map ? church['id'] as int? : null;
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// The API accepts a time of day in `from` and `until` and filters on it.
  String _formatDateTime(DateTime time) =>
      '${_formatDate(time)} '
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  Future<Map<String, dynamic>?> _post(
      String endpoint, Map<String, dynamic> payload) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/v4/$endpoint'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(payload),
      );
      if (response.statusCode != HttpStatus.ok) return null;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic> || _failed(decoded)) return null;
      return decoded;
    } on Exception {
      return null;
    }
  }

  /// The `error` field is the number 0 on success but a string on failure.
  bool _failed(Map<String, dynamic> body) {
    final error = body['error'];
    return error != null && error != 0 && error != '0';
  }

  ChurchDetails _churchFromJson(Map<String, dynamic> json) {
    return ChurchDetails(
      id: json['id'] as int,
      name: _text(json['nev']),
      commonName: _text(json['ismertnev']),
      names: _stringList(json['names']),
      alternativeNames: _stringList(json['alternative_names']),
      country: _text(json['orszag']),
      diocese: _text(json['egyhazmegye']),
      county: _text(json['megye']),
      city: _text(json['varos']),
      street: _text(json['cim']),
      gettingThere: _text(json['megkozelites']),
      parish: _text(json['plebania']),
      description: _text(json['leiras']),
      accessibility: json['accessibility'] is Map
          ? Map<String, dynamic>.from(json['accessibility'] as Map)
          : null,
      email: _text(json['email']),
      links: _stringList(json['links']),
      languages: _stringList(json['nyelvek']),
      massScheduleNote: _text(json['miserend_megjegyzes']),
      adorations: _adorations(json['adoraciok']),
      hasConfession: _boolean(json['gyontatas']),
      communities: _communities(json['kozossegek']),
      lat: _number(json['lat']),
      lon: _number(json['lon']),
      photos: _stringList(json['photos']).map(_absoluteUrl).toList(),
      updatedAt: parseApiDateTime(_text(json['frissitve'])),
      localSyncedAt: null,
      isGreek: null,
    );
  }

  List<Adoration> _adorations(dynamic value) {
    if (value is! List) return const <Adoration>[];
    return value.whereType<Map>().map((item) {
      return Adoration(
        start: parseApiDateTime(_text(item['kezdete'])),
        end: parseApiDateTime(_text(item['vege'])),
        kind: _text(item['fajta']),
        info: _text(item['info']),
      );
    }).toList();
  }

  List<Community> _communities(dynamic value) {
    if (value is! List) return const <Community>[];
    return value.whereType<Map>().map((item) {
      return Community(name: _text(item['nev']), link: _text(item['link']));
    }).toList();
  }

  String _absoluteUrl(String path) =>
      path.startsWith('http') ? path : '$baseUrl$path';

  /// Absent and empty are the same thing in this API: `megkozelites` and
  /// `miserend_megjegyzes` come back as empty strings rather than null.
  String? _text(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return value;
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return const <String>[];
    return value.whereType<String>().where((e) => e.isNotEmpty).toList();
  }

  double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  bool? _boolean(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return null;
  }
}

/// Mass and adoration times are wall-clock times at the church, and the API
/// writes them three ways: `2026-07-27 00:00:00`, `2026-09-10 00:00` and
/// `2026-09-10T17:00:00+02:00`. Applying that offset would move a 17:00 mass
/// for anyone whose phone is in another timezone, so it is read off, not
/// converted.
DateTime? parseApiDateTime(String? value) {
  if (value == null) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})(?::(\d{2}))?')
      .firstMatch(value);
  if (match == null) return null;
  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
    int.parse(match.group(6) ?? '0'),
  );
}
