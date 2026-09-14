import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miserend/api/miserend_api_client.dart';
import 'package:miserend/api/nearby_masses_item.dart';
import 'package:miserend/database/cache/cached_mass.dart';

http.Response _fixtureResponse(String name) => http.Response.bytes(
      File('test/fixtures/$name').readAsBytesSync(),
      200,
    );

void main() {
  group('fetchChurch', () {
    test('maps the scalar fields of a full church response', () async {
      final client = MiserendApiClient(
        client: MockClient((_) async => _fixtureResponse('church_38.json')),
      );

      final church = await client.fetchChurch(38);

      expect(church, isNotNull);
      expect(church!.id, 38);
      expect(church.name, 'Belvárosi Nagyboldogasszony-templom');
      expect(church.commonName, 'Belvárosi Nagyboldogasszony Főplébániatemplom');
      expect(church.country, 'Magyarország');
      expect(church.diocese, 'Esztergom-Budapest');
      expect(church.county, 'Budapest');
      expect(church.city, 'Budapest V. kerület');
      expect(church.street, 'Március 15. tér');
      expect(church.email, 'iroda.belvarosiplebania@gmail.com');
      expect(church.lat, 47.492233);
      expect(church.lon, 19.0522943);
      expect(church.updatedAt, DateTime(2026, 7, 27));
      expect(church.description, contains('Contra Aquincum'));
      expect(church.parish, startsWith('Pl&eacute;b&aacute;nos:'));
    });

    test('posts the church id and asks for the full response', () async {
      late http.Request sent;
      final client = MiserendApiClient(
        client: MockClient((request) async {
          sent = request;
          return _fixtureResponse('church_38.json');
        }),
      );

      await client.fetchChurch(38);

      expect(sent.method, 'POST');
      expect(sent.url.toString(), 'https://miserend.hu/api/v4/church');
      expect(jsonDecode(sent.body), {'id': 38, 'response_length': 'full'});
    });

    test('maps the list and object fields', () async {
      final client = MiserendApiClient(
        client: MockClient((_) async => _fixtureResponse('church_38.json')),
      );

      final church = (await client.fetchChurch(38))!;

      expect(church.photos, hasLength(7));
      expect(church.photos.first,
          'https://miserend.hu/kepek/templomok/38/8266570111.jpg');
      expect(church.links, [
        'http://belvarosiplebania.hu',
        'http://www.facebook.com/belvarosiplebaniatemplom',
      ]);
      expect(church.languages, ['hu', 'en', 'ua']);
      expect(church.names, hasLength(5));
      expect(church.alternativeNames, contains('Liebfrauenkirche'));
      expect(church.accessibility, {'wheelchair': 'no'});
      expect(church.hasConfession, isFalse);
      expect(church.communities, isEmpty);

      expect(church.adorations, hasLength(5));
      expect(church.adorations.first.start, DateTime(2026, 9, 10, 0, 0));
      expect(church.adorations.first.end, DateTime(2026, 9, 10, 23, 59));
      expect(church.adorations.first.kind, 'csendes');
      expect(church.adorations.first.info, isNull);

      final withInfo =
          church.adorations.firstWhere((a) => a.info != null);
      expect(withInfo.info, 'Kivéve júliusban és augusztusban');
      expect(withInfo.start, DateTime(2026, 9, 10, 16, 0));
    });

    test('maps communities, which are objects rather than names', () async {
      final client = MiserendApiClient(
        client: MockClient((_) async => _fixtureResponse('church_2.json')),
      );

      final church = (await client.fetchChurch(2))!;

      expect(church.communities, hasLength(1));
      expect(church.communities.first.name, 'Szent Imre Antióchia Közösség');
      expect(church.communities.first.link,
          'https://kozossegek.hu/kozosseg/szent-imre-antiochia-kozosseg-140');
    });

    test('leaves the empty strings of the response as null', () async {
      final client = MiserendApiClient(
        client: MockClient((_) async => _fixtureResponse('church_38.json')),
      );

      final church = (await client.fetchChurch(38))!;

      expect(church.gettingThere, isNull);
      expect(church.massScheduleNote, isNull);
    });

    test('never carries an isGreek value, which is bootstrap-only', () async {
      final client = MiserendApiClient(
        client: MockClient((_) async => _fixtureResponse('church_38.json')),
      );

      final church = (await client.fetchChurch(38))!;

      expect(church.isGreek, isNull);
    });

    test('returns null instead of throwing when the call fails', () async {
      final notFound = MiserendApiClient(
        client: MockClient((_) async => http.Response('', 404)),
      );
      final apiError = MiserendApiClient(
        client: MockClient(
            (_) async => http.Response('{"error":"1","text":"nope"}', 200)),
      );
      final offline = MiserendApiClient(
        client: MockClient((_) async => throw const SocketException('offline')),
      );

      expect(await notFound.fetchChurch(38), isNull);
      expect(await apiError.fetchChurch(38), isNull);
      expect(await offline.fetchChurch(38), isNull);
    });
  });

  group('fetchMassesForChurch', () {
    Future<List<CachedMass>> fetchWith(http.Response response) {
      final client = MiserendApiClient(client: MockClient((_) async => response));
      return client.fetchMassesForChurch(
        churchId: 38,
        lat: 47.492233,
        lon: 19.0522943,
        from: DateTime(2026, 9, 10),
        until: DateTime(2026, 9, 29),
      );
    }

    test('maps every occurrence of the nearby-masses response', () async {
      final masses = await fetchWith(_fixtureResponse('nearbymasses_38.json'));

      expect(masses, hasLength(25));
      expect(masses.first.churchId, 38);
      expect(masses.first.apiMassId, 129807);
      expect(masses.first.info, 'Szentmise');
      expect(masses.first.id, isNull);
    });

    test('reads the wall-clock time, not the offset-shifted one', () async {
      final masses = await fetchWith(_fixtureResponse('nearbymasses_38.json'));

      // The fixture says 2026-09-10T17:00:00+02:00, and the mass is at 17:00
      // whatever timezone the phone is in.
      expect(masses.first.time, DateTime(2026, 9, 10, 17, 0));
    });

    test('keeps the same mass id across its occurrences', () async {
      final masses = await fetchWith(_fixtureResponse('nearbymasses_38.json'));

      final recurring =
          masses.where((m) => m.apiMassId == 129807).toList();
      expect(recurring.length, greaterThan(1),
          reason: 'the API repeats one mass id for every occurrence');
      expect(recurring.map((m) => m.time).toSet(), hasLength(recurring.length));
    });

    test('drops occurrences belonging to another nearby church', () async {
      final body = jsonEncode({
        'error': 0,
        'sum': 2,
        'misek': [
          {
            'id': 1,
            'start_date': '2026-09-10T17:00:00+02:00',
            'title': 'Szentmise',
            'church': {'id': 38},
          },
          {
            'id': 2,
            'start_date': '2026-09-10T18:00:00+02:00',
            'title': 'Szentmise',
            'church': {'id': 99},
          },
        ],
      });

      final masses = await fetchWith(http.Response.bytes(utf8.encode(body), 200));

      expect(masses, hasLength(1));
      expect(masses.single.apiMassId, 1);
    });

    test('skips an occurrence with no usable time', () async {
      final body = jsonEncode({
        'error': 0,
        'sum': 2,
        'misek': [
          {
            'id': 1,
            'start_date': null,
            'title': 'Szentmise',
            'church': {'id': 38},
          },
          {
            'id': 2,
            'start_date': '2026-09-10T18:00:00+02:00',
            'title': 'Szentmise',
            'church': {'id': 38},
          },
        ],
      });

      final masses = await fetchWith(http.Response.bytes(utf8.encode(body), 200));

      expect(masses, hasLength(1));
      expect(masses.single.apiMassId, 2);
    });

    test('asks for the narrow radius and the date range', () async {
      Map<String, dynamic>? sent;
      final client = MiserendApiClient(client: MockClient((request) async {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return _fixtureResponse('nearbymasses_38.json');
      }));

      await client.fetchMassesForChurch(
        churchId: 38,
        lat: 47.492233,
        lon: 19.0522943,
        from: DateTime(2026, 9, 10),
        until: DateTime(2026, 9, 29),
      );

      expect(sent, {
        'lat': 47.492233,
        'lon': 19.0522943,
        'radius': 0.1,
        'from': '2026-09-10',
        'until': '2026-09-29',
        'limit': 100,
      });
    });

    test('returns nothing instead of throwing when the call fails', () async {
      expect(await fetchWith(http.Response('', 500)), isEmpty);
      expect(
          await fetchWith(http.Response(
              '{"error":"1","text":"Field \'limit\' should be at most 100."}',
              200)),
          isEmpty);

      final offline = MiserendApiClient(
        client: MockClient((_) async => throw const SocketException('offline')),
      );
      expect(
          await offline.fetchMassesForChurch(
            churchId: 38,
            lat: 47.492233,
            lon: 19.0522943,
            from: DateTime(2026, 9, 10),
            until: DateTime(2026, 9, 29),
          ),
          isEmpty);
    });
  });

  group('fetchNearbyMasses', () {
    // Recorded live for a position in central Budapest, 2026-09-14 15:45.
    const fixture = 'nearbymasses_budapest_2026-09-14_1545.json';

    Future<List<NearbyMassesItem>?> fetchWith(http.Response response) {
      final client = MiserendApiClient(client: MockClient((_) async => response));
      return client.fetchNearbyMasses(
        lat: 47.4979,
        lon: 19.0402,
        from: DateTime(2026, 9, 14, 15, 45),
        until: DateTime(2026, 9, 15),
      );
    }

    test('maps every item of the response, church fields included', () async {
      final masses = (await fetchWith(_fixtureResponse(fixture)))!;

      expect(masses, hasLength(100));
      final first = masses.first;
      expect(first.churchId, 1515);
      expect(first.churchName, 'Budavári Nagyboldogasszony-templom');
      expect(first.city, 'Budapest I. kerület');
      expect(first.lat, 47.5020112);
      expect(first.lon, 19.0342625);
      expect(first.distanceKm, 0.64);
      expect(first.title, 'Szentmise');
    });

    test('reads the start as the wall-clock time at the church', () async {
      final masses = (await fetchWith(_fixtureResponse(fixture)))!;

      // The fixture says 2026-09-14T18:00:00+02:00.
      expect(masses.first.start, DateTime(2026, 9, 14, 18, 0));
    });

    test('keeps the items that are not masses, for the caller to filter',
        () async {
      final masses = (await fetchWith(_fixtureResponse(fixture)))!;

      expect(masses.map((m) => m.title), contains('Gyóntatás'));
    });

    test('asks for the wide radius, the time-of-day window and the limit',
        () async {
      Map<String, dynamic>? sent;
      Uri? url;
      final client = MiserendApiClient(client: MockClient((request) async {
        url = request.url;
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return _fixtureResponse(fixture);
      }));

      await client.fetchNearbyMasses(
        lat: 47.4979,
        lon: 19.0402,
        from: DateTime(2026, 9, 14, 15, 45),
        until: DateTime(2026, 9, 15),
      );

      expect(url.toString(), 'https://miserend.hu/api/v4/nearbymasses');
      expect(sent, {
        'lat': 47.4979,
        'lon': 19.0402,
        'radius': 200,
        'from': '2026-09-14 15:45',
        'until': '2026-09-15 00:00',
        'limit': 100,
      });
    });

    test('an empty response is an empty list', () async {
      final masses = await fetchWith(
          http.Response('{"error":0,"sum":0,"misek":[]}', 200));

      expect(masses, isNotNull);
      expect(masses, isEmpty);
    });

    test('a failed call is null, not an empty list', () async {
      expect(await fetchWith(http.Response('', 500)), isNull);
      expect(
          await fetchWith(http.Response(
              '{"error":"1","text":"Field \'radius\' should be at most 200."}',
              200)),
          isNull);
      expect(await fetchWith(http.Response('{"error":0,"sum":0}', 200)),
          isNull);

      final offline = MiserendApiClient(
        client: MockClient((_) async => throw const SocketException('offline')),
      );
      expect(
          await offline.fetchNearbyMasses(
            lat: 47.4979,
            lon: 19.0402,
            from: DateTime(2026, 9, 14, 15, 45),
            until: DateTime(2026, 9, 15),
          ),
          isNull);
    });

    test('skips an item with no usable church or start', () async {
      final body = jsonEncode({
        'error': 0,
        'sum': 3,
        'misek': [
          {'id': 1, 'start_date': null, 'title': 'Szentmise',
            'distance_km': 1, 'church': {'id': 38}},
          {'id': 2, 'start_date': '2026-09-14T18:00:00+02:00',
            'title': 'Szentmise', 'distance_km': 1},
          {'id': 3, 'start_date': '2026-09-14T18:00:00+02:00',
            'title': 'Szentmise', 'distance_km': 1, 'church': {'id': 38}},
        ],
      });

      final masses =
          (await fetchWith(http.Response.bytes(utf8.encode(body), 200)))!;

      expect(masses, hasLength(1));
      expect(masses.single.churchId, 38);
    });
  });
}
