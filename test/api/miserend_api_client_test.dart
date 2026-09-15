import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miserend/api/api_result.dart';
import 'package:miserend/api/miserend_api_client.dart';
import 'package:miserend/api/nearby_masses_item.dart';
import 'package:miserend/database/cache/cached_mass.dart';
import 'package:miserend/database/cache/church_details.dart';

http.Response _fixtureResponse(String name) =>
    http.Response.bytes(File('test/fixtures/$name').readAsBytesSync(), 200);

void main() {
  group('fetchChurches', () {
    /// The single-church recording, in the shape the `ids` form answers with.
    http.Response idsResponse(String fixture, {List<int> missing = const []}) {
      final church =
          jsonDecode(File('test/fixtures/$fixture').readAsStringSync())
                as Map<String, dynamic>
            ..remove('error');
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'templomok': [church],
            'hianyzo': missing,
            'error': 0,
          }),
        ),
        200,
      );
    }

    Future<ChurchDetails> fetchOne(String fixture) async {
      final client = MiserendApiClient(
        client: MockClient((_) async => idsResponse(fixture)),
      );
      final result = await client.fetchChurches([38]);
      return (result as ApiSuccess<ChurchesResponse>).value.churches.single;
    }

    test('maps the scalar fields of a full church response', () async {
      final church = await fetchOne('church_38.json');

      expect(church.id, 38);
      expect(church.name, 'Belvárosi Nagyboldogasszony-templom');
      expect(
        church.commonName,
        'Belvárosi Nagyboldogasszony Főplébániatemplom',
      );
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

    test('asks in the ids form, which reports a missing church instead of '
        'failing', () async {
      late http.Request sent;
      final client = MiserendApiClient(
        client: MockClient((request) async {
          sent = request;
          return idsResponse('church_38.json');
        }),
      );

      await client.fetchChurches([38], length: ResponseLength.full);

      expect(sent.method, 'POST');
      expect(sent.url.toString(), 'https://miserend.hu/api/v4/church');
      expect(jsonDecode(sent.body), {
        'ids': [38],
        'response_length': 'full',
      });
    });

    test('reads the recorded ids response, missing ids included', () async {
      // Recorded live on 2026-09-15 for ids 1515, 38 and 999999.
      final client = MiserendApiClient(
        client: MockClient(
          (_) async => _fixtureResponse('church_ids_hianyzo_2026-09-15.json'),
        ),
      );

      final result = await client.fetchChurches([1515, 38, 999999]);

      final response = (result as ApiSuccess<ChurchesResponse>).value;
      expect(response.churches.map((c) => c.id), [1515, 38]);
      expect(response.churches.first.commonName, 'Mátyás-templom');
      expect(response.missing, [999999]);
      expect(response.massesOf(38).single.time, DateTime(2026, 9, 15, 17, 0));
    });

    test('maps the list and object fields', () async {
      final church = await fetchOne('church_38.json');

      expect(church.photos, hasLength(7));
      expect(
        church.photos.first,
        'https://miserend.hu/kepek/templomok/38/8266570111.jpg',
      );
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

      final withInfo = church.adorations.firstWhere((a) => a.info != null);
      expect(withInfo.info, 'Kivéve júliusban és augusztusban');
      expect(withInfo.start, DateTime(2026, 9, 10, 16, 0));
    });

    test('maps communities, which are objects rather than names', () async {
      final church = await fetchOne('church_2.json');

      expect(church.communities, hasLength(1));
      expect(church.communities.first.name, 'Szent Imre Antióchia Közösség');
      expect(
        church.communities.first.link,
        'https://kozossegek.hu/kozosseg/szent-imre-antiochia-kozosseg-140',
      );
    });

    test('leaves the empty strings of the response as null', () async {
      final church = await fetchOne('church_38.json');

      expect(church.gettingThere, isNull);
      expect(church.massScheduleNote, isNull);
    });

    test('never carries an isGreek value, which is bootstrap-only', () async {
      final church = await fetchOne('church_38.json');

      expect(church.isGreek, isNull);
    });

    test(
      'asks for more than a hundred churches in batches of a hundred',
      () async {
        final sent = <List<dynamic>>[];
        final client = MiserendApiClient(
          client: MockClient((request) async {
            final ids =
                (jsonDecode(request.body) as Map)['ids'] as List<dynamic>;
            sent.add(ids);
            return http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  'templomok': [
                    for (final id in ids) {'id': id, 'nev': 'Templom $id'},
                  ],
                  'hianyzo': ids.contains(150) ? [150] : [],
                  'error': 0,
                }),
              ),
              200,
            );
          }),
        );

        final result = await client.fetchChurches([
          for (var id = 1; id <= 250; id++) id,
        ]);

        expect(sent.map((ids) => ids.length), [100, 100, 50]);
        expect(sent.expand((ids) => ids), [
          for (var id = 1; id <= 250; id++) id,
        ]);
        final response = (result as ApiSuccess<ChurchesResponse>).value;
        expect(response.churches, hasLength(250));
        expect(response.missing, [150]);
      },
    );

    test('a failed batch fails the whole call', () async {
      var calls = 0;
      final client = MiserendApiClient(
        client: MockClient((request) async {
          calls++;
          if (calls == 2) return http.Response('', 500);
          return http.Response('{"templomok":[],"hianyzo":[],"error":0}', 200);
        }),
      );

      final result = await client.fetchChurches([
        for (var id = 1; id <= 150; id++) id,
      ]);

      expect((result as ApiFailed).failure, ApiFailure.serverError);
    });

    test('asks nothing for no ids', () async {
      var calls = 0;
      final client = MiserendApiClient(
        client: MockClient((request) async {
          calls++;
          return http.Response('', 500);
        }),
      );

      final result = await client.fetchChurches(const []);

      expect(calls, 0);
      expect((result as ApiSuccess<ChurchesResponse>).value.churches, isEmpty);
    });

    test('a response without the church list is a server error', () async {
      final client = MiserendApiClient(
        client: MockClient((_) async => http.Response('{"error":0}', 200)),
      );

      final result = await client.fetchChurches([38]);

      expect((result as ApiFailed).failure, ApiFailure.serverError);
    });
  });

  group('outcomes', () {
    /// Every call of the client, each run against the same fake transport.
    final calls =
        <String, Future<ApiResult<Object>> Function(MiserendApiClient)>{
          'church': (api) => api.fetchChurches([38]),
          'masses for a church':
              (api) => api.fetchMassesForChurch(
                churchId: 38,
                lat: 47.492233,
                lon: 19.0522943,
                from: DateTime(2026, 9, 10),
                until: DateTime(2026, 9, 29),
              ),
          'search': (api) => api.searchChurches('Szeged'),
          'nearby churches':
              (api) => api.fetchNearbyChurches(lat: 47.4979, lon: 19.0402),
          'nearby masses':
              (api) => api.fetchNearbyMasses(
                lat: 47.4979,
                lon: 19.0402,
                from: DateTime(2026, 9, 14, 15, 45),
                until: DateTime(2026, 9, 15),
              ),
        };

    Future<ApiFailure?> failureOf(
      Future<ApiResult<Object>> Function(MiserendApiClient) call,
      Future<http.Response> Function(http.Request) transport,
    ) async {
      final result = await call(
        MiserendApiClient(client: MockClient(transport)),
      );
      return switch (result) {
        ApiSuccess() => null,
        ApiFailed(:final failure) => failure,
      };
    }

    for (final MapEntry(key: name, value: call) in calls.entries) {
      group(name, () {
        test('a socket error is no connection', () async {
          expect(
            await failureOf(
              call,
              (_) async => throw const SocketException('offline'),
            ),
            ApiFailure.noConnection,
          );
        });

        test('a TLS handshake error is no connection', () async {
          expect(
            await failureOf(
              call,
              (_) async => throw const HandshakeException('tls'),
            ),
            ApiFailure.noConnection,
          );
        });

        test('an HTTP error status is a server error', () async {
          expect(
            await failureOf(call, (_) async => http.Response('', 500)),
            ApiFailure.serverError,
          );
        });

        test('an error flag in the payload is a server error', () async {
          expect(
            await failureOf(
              call,
              (_) async => http.Response.bytes(
                utf8.encode(
                  '{"error":"Nem létezik misézőhely ezzel '
                  'az asonosítóval."}',
                ),
                200,
              ),
            ),
            ApiFailure.serverError,
          );
        });

        test('JSON that does not parse is a server error', () async {
          expect(
            await failureOf(
              call,
              (_) async => http.Response('<html>oops</html>', 200),
            ),
            ApiFailure.serverError,
          );
        });
      });
    }

    testWidgets('a call with no answer in 15 seconds is no connection', (
      tester,
    ) async {
      // testWidgets runs on a fake clock, so the wait costs nothing.
      final never = Completer<http.Response>();
      final api = MiserendApiClient(client: MockClient((_) => never.future));

      ApiResult<ChurchesResponse>? result;
      unawaited(api.fetchChurches([38]).then((value) => result = value));

      await tester.pump(const Duration(seconds: 14));
      expect(result, isNull);

      await tester.pump(const Duration(seconds: 1));
      expect((result as ApiFailed).failure, ApiFailure.noConnection);
    });

    test('the limits are the ones the spec sets', () {
      expect(MiserendApiClient.callTimeout, const Duration(seconds: 15));
      expect(MiserendApiClient.connectTimeout, const Duration(seconds: 10));
    });

    test('the connection the calls go through gives up connecting after '
        '10 seconds', () {
      final client = MiserendApiClient.newHttpClient();
      addTearDown(client.close);

      expect(client.connectionTimeout, const Duration(seconds: 10));
    });
  });

  group('searchChurches', () {
    // Recorded live for "Szeged", 2026-09-15.
    const fixture = 'search_szeged_2026-09-15.json';

    test('maps the churches and their masses of the day', () async {
      final client = MiserendApiClient(
        client: MockClient((_) async => _fixtureResponse(fixture)),
      );

      final result = await client.searchChurches('Szeged');

      final response = (result as ApiSuccess<ChurchesResponse>).value;
      expect(response.churches, hasLength(17));
      final first = response.churches.first;
      expect(first.id, 1155);
      expect(first.name, 'Havas Boldogasszony templom');
      expect(first.commonName, 'Alsóvárosi templom, Ferences templom');
      expect(first.city, 'Szeged');
      expect(response.massesOf(1155).map((m) => m.time), [
        DateTime(2026, 9, 15, 7, 0),
        DateTime(2026, 9, 15, 18, 0),
      ]);
    });

    test('asks for a hundred results, minimal', () async {
      late http.Request sent;
      final client = MiserendApiClient(
        client: MockClient((request) async {
          sent = request;
          return _fixtureResponse(fixture);
        }),
      );

      await client.searchChurches('Szeged');

      expect(sent.url.toString(), 'https://miserend.hu/api/v4/search');
      expect(jsonDecode(sent.body), {
        'q': 'Szeged',
        'limit': 100,
        'response_length': 'minimal',
      });
    });
  });

  group('fetchNearbyChurches', () {
    // Recorded live for a position in central Budapest, 2026-09-15.
    const fixture = 'nearby_budapest_2026-09-15.json';

    Future<ChurchesResponse> fetchWith(http.Response response) async {
      final client = MiserendApiClient(
        client: MockClient((_) async => response),
      );
      final result = await client.fetchNearbyChurches(
        lat: 47.4979,
        lon: 19.0402,
      );
      return (result as ApiSuccess<ChurchesResponse>).value;
    }

    test('maps the churches, nearest first', () async {
      final response = await fetchWith(_fixtureResponse(fixture));

      expect(response.churches, hasLength(100));
      expect(response.churches.take(3).map((c) => c.id), [2721, 1514, 1515]);
      final first = response.churches.first;
      expect(first.name, 'Árpád-házi Szent Erzsébet-templom');
      expect(first.city, 'Budapest I. kerület');
      expect(first.lat, 47.5021615);
      expect(first.lon, 19.0385385);
      expect(response.missing, isEmpty);
    });

    test(
      "maps each church's masses of the day, marked as a list answer",
      () async {
        final response = await fetchWith(_fixtureResponse(fixture));

        final masses = response.massesOf(1515);
        expect(masses.map((m) => m.time), [
          DateTime(2026, 9, 15, 7, 0),
          DateTime(2026, 9, 15, 18, 0),
        ]);
        expect(masses.first.info, 'Római katolikus Szentmise, Csendes');
        expect(masses.first.churchId, 1515);
        expect(masses.map((m) => m.source).toSet(), {MassSource.dailyList});
        expect(response.massesOf(2721), isEmpty);
      },
    );

    test('asks for a hundred churches around the position, minimal', () async {
      late http.Request sent;
      final client = MiserendApiClient(
        client: MockClient((request) async {
          sent = request;
          return _fixtureResponse(fixture);
        }),
      );

      await client.fetchNearbyChurches(lat: 47.4979, lon: 19.0402);

      expect(sent.url.toString(), 'https://miserend.hu/api/v4/nearby');
      expect(jsonDecode(sent.body), {
        'lat': 47.4979,
        'lon': 19.0402,
        'limit': 100,
        'response_length': 'minimal',
      });
    });
  });

  group('fetchMassesForChurch', () {
    Future<List<CachedMass>> fetchWith(http.Response response) async {
      final client = MiserendApiClient(
        client: MockClient((_) async => response),
      );
      final result = await client.fetchMassesForChurch(
        churchId: 38,
        lat: 47.492233,
        lon: 19.0522943,
        from: DateTime(2026, 9, 10),
        until: DateTime(2026, 9, 29),
      );
      return (result as ApiSuccess<List<CachedMass>>).value;
    }

    test('maps every occurrence of the nearby-masses response', () async {
      final masses = await fetchWith(_fixtureResponse('nearbymasses_38.json'));

      expect(masses, hasLength(25));
      expect(masses.first.churchId, 38);
      expect(masses.first.apiMassId, 129807);
      expect(masses.first.info, 'Szentmise');
      expect(masses.first.id, isNull);
      expect(masses.map((m) => m.source).toSet(), {MassSource.nearbyMasses});
    });

    test('reads the wall-clock time, not the offset-shifted one', () async {
      final masses = await fetchWith(_fixtureResponse('nearbymasses_38.json'));

      // The fixture says 2026-09-10T17:00:00+02:00, and the mass is at 17:00
      // whatever timezone the phone is in.
      expect(masses.first.time, DateTime(2026, 9, 10, 17, 0));
    });

    test('keeps the same mass id across its occurrences', () async {
      final masses = await fetchWith(_fixtureResponse('nearbymasses_38.json'));

      final recurring = masses.where((m) => m.apiMassId == 129807).toList();
      expect(
        recurring.length,
        greaterThan(1),
        reason: 'the API repeats one mass id for every occurrence',
      );
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

      final masses = await fetchWith(
        http.Response.bytes(utf8.encode(body), 200),
      );

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

      final masses = await fetchWith(
        http.Response.bytes(utf8.encode(body), 200),
      );

      expect(masses, hasLength(1));
      expect(masses.single.apiMassId, 2);
    });

    test('asks for the narrow radius and the date range', () async {
      Map<String, dynamic>? sent;
      final client = MiserendApiClient(
        client: MockClient((request) async {
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          return _fixtureResponse('nearbymasses_38.json');
        }),
      );

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

    test('an answer with no masses is a success with none', () async {
      expect(
        await fetchWith(http.Response('{"error":0,"sum":0,"misek":[]}', 200)),
        isEmpty,
      );
    });
  });

  group('fetchNearbyMasses', () {
    // Recorded live for a position in central Budapest, 2026-09-14 15:45.
    const fixture = 'nearbymasses_budapest_2026-09-14_1545.json';

    Future<ApiResult<List<NearbyMassesItem>>> resultWith(
      http.Response response,
    ) {
      final client = MiserendApiClient(
        client: MockClient((_) async => response),
      );
      return client.fetchNearbyMasses(
        lat: 47.4979,
        lon: 19.0402,
        from: DateTime(2026, 9, 14, 15, 45),
        until: DateTime(2026, 9, 15),
      );
    }

    Future<List<NearbyMassesItem>> fetchWith(http.Response response) async =>
        ((await resultWith(response)) as ApiSuccess<List<NearbyMassesItem>>)
            .value;

    test('maps every item of the response, church fields included', () async {
      final masses = await fetchWith(_fixtureResponse(fixture));

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
      final masses = await fetchWith(_fixtureResponse(fixture));

      // The fixture says 2026-09-14T18:00:00+02:00.
      expect(masses.first.start, DateTime(2026, 9, 14, 18, 0));
    });

    test(
      'keeps the items that are not masses, for the caller to filter',
      () async {
        final masses = await fetchWith(_fixtureResponse(fixture));

        expect(masses.map((m) => m.title), contains('Gyóntatás'));
      },
    );

    test(
      'asks for the wide radius, the time-of-day window and the limit',
      () async {
        Map<String, dynamic>? sent;
        Uri? url;
        final client = MiserendApiClient(
          client: MockClient((request) async {
            url = request.url;
            sent = jsonDecode(request.body) as Map<String, dynamic>;
            return _fixtureResponse(fixture);
          }),
        );

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
      },
    );

    test('an empty response is an empty list', () async {
      final masses = await fetchWith(
        http.Response('{"error":0,"sum":0,"misek":[]}', 200),
      );

      expect(masses, isEmpty);
    });

    test('a response without the item list is a server error', () async {
      final result = await resultWith(
        http.Response('{"error":0,"sum":0}', 200),
      );

      expect((result as ApiFailed).failure, ApiFailure.serverError);
    });

    test('skips an item with no usable church or start', () async {
      final body = jsonEncode({
        'error': 0,
        'sum': 3,
        'misek': [
          {
            'id': 1,
            'start_date': null,
            'title': 'Szentmise',
            'distance_km': 1,
            'church': {'id': 38},
          },
          {
            'id': 2,
            'start_date': '2026-09-14T18:00:00+02:00',
            'title': 'Szentmise',
            'distance_km': 1,
          },
          {
            'id': 3,
            'start_date': '2026-09-14T18:00:00+02:00',
            'title': 'Szentmise',
            'distance_km': 1,
            'church': {'id': 38},
          },
        ],
      });

      final masses = await fetchWith(
        http.Response.bytes(utf8.encode(body), 200),
      );

      expect(masses, hasLength(1));
      expect(masses.single.churchId, 38);
    });
  });
}
