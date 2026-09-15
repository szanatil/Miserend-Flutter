import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:miserend/api/api_result.dart';
import 'package:miserend/api/nearby_masses_item.dart';
import 'package:miserend/database/cache/adoration.dart';
import 'package:miserend/database/cache/cached_mass.dart';
import 'package:miserend/database/cache/church_details.dart';
import 'package:miserend/database/cache/community.dart';

/// How much of a church the API sends back. `minimal` leaves out, among
/// others, the photos, the description and the names; see [CacheDatabase]'s
/// partial write.
enum ResponseLength { minimal, full }

/// The answer of the `Church` endpoint in its `ids` form.
class ChurchesResponse {
  const ChurchesResponse({required this.churches, required this.missing});

  final List<ChurchDetails> churches;

  /// Ids the API no longer knows: the church has been removed from
  /// miserend.hu.
  final List<int> missing;
}

/// Reads the miserend.hu v4 JSON API. Every call tells a successful answer —
/// an empty one included — apart from the two ways of getting none (see
/// [ApiFailure]), because the screens word those differently.
class MiserendApiClient {
  static const String baseUrl = 'https://miserend.hu';

  /// The longest a call may take, answer included. Past it the call counts as
  /// no connection: a phone on a weak signal must not spin forever.
  static const Duration callTimeout = Duration(seconds: 15);

  /// The longest connecting may take, within [callTimeout].
  static const Duration connectTimeout = Duration(seconds: 10);

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

  MiserendApiClient({http.Client? client})
      : _client = client ??
            IOClient(HttpClient()..connectionTimeout = connectTimeout);

  /// The churches with these ids. Always the `ids` form, even for one church:
  /// asked for by a single `id`, a church that no longer exists is an error
  /// response, which would read as a server error rather than as [missing].
  Future<ApiResult<ChurchesResponse>> fetchChurches(
    List<int> ids, {
    ResponseLength length = ResponseLength.minimal,
  }) async {
    final result = await _post('church', {
      'ids': ids,
      'response_length': length.name,
    });
    return _map(result, (body) {
      final churches = body['templomok'];
      if (churches is! List) return null;
      final missing = body['hianyzo'];
      return ChurchesResponse(
        churches: _churches(churches),
        missing: missing is List
            ? missing.whereType<int>().toList()
            : const <int>[],
      );
    });
  }

  /// The masses [churchId] holds between [from] and [until]. The response can
  /// carry a second church that shares the coordinates, so it is filtered by
  /// church id here as well.
  Future<ApiResult<List<CachedMass>>> fetchMassesForChurch({
    required int churchId,
    required double lat,
    required double lon,
    required DateTime from,
    required DateTime until,
  }) async {
    final result = await _post('nearbymasses', {
      'lat': lat,
      'lon': lon,
      'radius': _selfRadiusKm,
      'from': _formatDate(from),
      'until': _formatDate(until),
      'limit': _massLimit,
    });
    return _map(result, (body) {
      final masses = body['misek'];
      if (masses is! List) return null;

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
          source: MassSource.nearbyMasses,
        ));
      }
      return occurrences;
    });
  }

  /// Everything the API holds within [_nearbyRadiusKm] of the position,
  /// starting between [from] and [until], nearest first — masses and other
  /// liturgical events alike.
  Future<ApiResult<List<NearbyMassesItem>>> fetchNearbyMasses({
    required double lat,
    required double lon,
    required DateTime from,
    required DateTime until,
  }) async {
    final result = await _post('nearbymasses', {
      'lat': lat,
      'lon': lon,
      'radius': _nearbyRadiusKm,
      'from': _formatDateTime(from),
      'until': _formatDateTime(until),
      'limit': _massLimit,
    });
    return _map(result, (body) {
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
    });
  }

  List<ChurchDetails> _churches(List<dynamic> items) => items
      .whereType<Map<String, dynamic>>()
      .where((item) => item['id'] is int)
      .map(_churchFromJson)
      .toList();

  /// Reads a successful body with [read]; a body [read] cannot make sense of
  /// (it returns null) is a server error like any other malformed answer.
  ApiResult<T> _map<T>(ApiResult<Map<String, dynamic>> result,
      T? Function(Map<String, dynamic> body) read) {
    switch (result) {
      case ApiFailed(:final failure):
        return ApiFailed(failure);
      case ApiSuccess(:final value):
        final mapped = read(value);
        return mapped == null
            ? const ApiFailed(ApiFailure.serverError)
            : ApiSuccess(mapped);
    }
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

  /// Anything thrown before a response arrives means the request did not get
  /// through — socket, DNS, TLS, the connect timeout, [callTimeout]. Anything
  /// wrong with the response itself is the server's.
  Future<ApiResult<Map<String, dynamic>>> _post(
      String endpoint, Map<String, dynamic> payload) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$baseUrl/api/v4/$endpoint'),
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode(payload),
          )
          .timeout(callTimeout);
    } on Exception {
      return const ApiFailed(ApiFailure.noConnection);
    }

    if (response.statusCode != HttpStatus.ok) {
      return const ApiFailed(ApiFailure.serverError);
    }
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic> || _failed(decoded)) {
        return const ApiFailed(ApiFailure.serverError);
      }
      return ApiSuccess(decoded);
    } on FormatException {
      return const ApiFailed(ApiFailure.serverError);
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
