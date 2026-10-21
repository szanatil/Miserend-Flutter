import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miserend/api/api_result.dart';
import 'package:miserend/api/miserend_api_client.dart';
import 'package:miserend/church_details/church_schedule_loader.dart';
import 'package:miserend/database/cache/bootstrap_importer.dart';
import 'package:miserend/database/cache/cache_database.dart';
import 'package:miserend/database/cache/cached_mass.dart';
import 'package:miserend/database/church.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final DateTime _today = DateTime(2026, 9, 10);

final Church _church = Church(
  id: 38,
  name: 'Belvárosi Nagyboldogasszony-templom',
  commonName: 'Főplébániatemplom',
  isGreek: false,
  lat: 47.492233,
  lon: 19.0522943,
  address: null,
  city: 'Budapest',
  country: 'Magyarország',
  county: 'Budapest',
  street: 'Március 15. tér',
  gettingThere: null,
  imageUrl: null,
);

CachedMass _mass(DateTime time, String info) => CachedMass(
  id: null,
  apiMassId: null,
  churchId: 38,
  time: time,
  info: info,
  source: MassSource.nearbyMasses,
);

/// The church's masses at [times], after [nearer] items of a church that
/// stands nearer: the API groups its answer by church, nearest first. Every
/// item is of the same mass unless [massIds] gives each its own.
String _nearbyMassesAt(
  List<DateTime> times, {
  int nearer = 0,
  List<int>? massIds,
}) {
  String two(int n) => n.toString().padLeft(2, '0');
  var index = 0;
  Map<String, Object> item(int id, DateTime time) => {
    'id': id == 38 && massIds != null ? massIds[index++] : 129807,
    'start_date':
        '${time.year}-${two(time.month)}-${two(time.day)}'
        'T${two(time.hour)}:${two(time.minute)}:00+02:00',
    'title': 'Szentmise',
    'church': {'id': id},
  };
  return jsonEncode({
    'error': 0,
    'sum': nearer + times.length,
    'misek': [
      for (var i = 0; i < nearer; i++)
        item(99, DateTime(2026, 9, 10, 6, 0).add(Duration(minutes: i))),
      for (final time in times) item(38, time),
    ],
  });
}

/// The recorded church, in the shape the `ids` form of the call answers with;
/// [todayMasses], if given, stand in for its `misek`.
http.Response _churchResponse({
  bool? confession,
  List<Map<String, String>>? todayMasses,
}) {
  final church =
      jsonDecode(File('test/fixtures/church_38.json').readAsStringSync())
            as Map<String, dynamic>
        ..remove('error');
  // The recording has the switch off, which every live church does; flipping
  // it here is the only way to exercise the rare case.
  if (confession != null) {
    church['gyontatas'] = confession;
  }
  if (todayMasses != null) {
    church['misek'] = todayMasses;
  }
  return http.Response.bytes(
    utf8.encode(
      jsonEncode({
        'templomok': [church],
        'hianyzo': [],
        'error': 0,
      }),
    ),
    200,
  );
}

/// Answers the church call from the recorded response and the masses call from
/// [massTimes]; [failure] makes every call fail that way, [churchFailure] only
/// the church call.
MiserendApiClient _api({
  List<DateTime> massTimes = const [],
  List<int>? massIds,
  int nearer = 0,
  ApiFailure? failure,
  ApiFailure? churchFailure,
  bool? confession,
  List<Map<String, String>>? todayMasses,
}) {
  return MiserendApiClient(
    client: MockClient((request) async {
      final isMasses = request.url.path.endsWith('nearbymasses');
      switch (failure ?? (isMasses ? null : churchFailure)) {
        case ApiFailure.noConnection:
          throw const SocketException('offline');
        case ApiFailure.serverError:
          return http.Response('', 500);
        case null:
          break;
      }
      if (isMasses) {
        return http.Response.bytes(
          utf8.encode(
            _nearbyMassesAt(massTimes, nearer: nearer, massIds: massIds),
          ),
          200,
        );
      }
      return _churchResponse(confession: confession, todayMasses: todayMasses);
    }),
  );
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late CacheDatabase cache;

  setUp(() async {
    cache = await CacheDatabase.create(path: inMemoryDatabasePath);
  });

  tearDown(() async => cache.db.close());

  group('loadCached', () {
    test('buckets the cached masses by day', () async {
      await cache.replaceMassesForChurch(38, [
        _mass(DateTime(2026, 9, 10, 17, 0), 'Ma'),
        _mass(DateTime(2026, 9, 10, 18, 30), 'Ma este'),
        _mass(DateTime(2026, 9, 13, 10, 0), 'Vasárnap'),
      ]);

      final days =
          (await ChurchScheduleLoader(
            cache: cache,
            api: _api(),
          ).loadCached(38, _today)).massesByDay;

      expect(days, hasLength(ChurchScheduleLoader.scheduleDays));
      expect(days[0].map((m) => m.info), ['Ma', 'Ma este']);
      expect(days[1], isEmpty);
      expect(days[3].map((m) => m.info), ['Vasárnap']);
    });

    test('a mass after the clocks go back lands on its own day, and one '
        'after they go forward too', () async {
      // 2026-10-25 has 25 hours; 2027-03-28 has 23.
      final today = DateTime(2026, 10, 8);
      await cache.replaceMassesForChurch(38, [
        _mass(DateTime(2026, 10, 26, 7, 0), 'Hétfő'),
      ]);
      final autumn =
          (await ChurchScheduleLoader(
            cache: cache,
            api: _api(),
          ).loadCached(38, today)).massesByDay;

      expect(autumn[18].map((m) => m.info), ['Hétfő']);

      final spring = DateTime(2027, 3, 20);
      await cache.replaceMassesForChurch(38, [
        _mass(DateTime(2027, 3, 29, 7, 0), 'Hétfő'),
      ]);
      final days =
          (await ChurchScheduleLoader(
            cache: cache,
            api: _api(),
          ).loadCached(38, spring)).massesByDay;

      expect(days[9].map((m) => m.info), ['Hétfő']);
    });

    test('leaves out what falls outside the window', () async {
      await cache.replaceMassesForChurch(38, [
        _mass(DateTime(2026, 9, 9, 17, 0), 'Tegnap'),
        _mass(DateTime(2026, 10, 30, 17, 0), 'Jövő hónap'),
      ]);

      final days =
          (await ChurchScheduleLoader(
            cache: cache,
            api: _api(),
          ).loadCached(38, _today)).massesByDay;

      expect(days.expand((day) => day), isEmpty);
    });

    test('is all empty for a church with nothing cached', () async {
      final days =
          (await ChurchScheduleLoader(
            cache: cache,
            api: _api(),
          ).loadCached(38, _today)).massesByDay;

      expect(days, hasLength(ChurchScheduleLoader.scheduleDays));
      expect(days.expand((day) => day), isEmpty);
    });

    test('is fresh on no day: only the cache speaks', () async {
      await cache.replaceMassesForChurch(38, [
        _mass(DateTime(2026, 9, 10, 9, 0), 'Bootstrap mise'),
      ]);

      final page = await ChurchScheduleLoader(
        cache: cache,
        api: _api(),
      ).loadCached(38, _today);

      expect(page.freshDays, 0);
    });
  });

  group('refresh', () {
    test('replaces the cached masses with the API answer', () async {
      await cache.replaceMassesForChurch(38, [
        _mass(DateTime(2026, 9, 11, 9, 0), 'Bootstrap mise'),
      ]);

      final loader = ChurchScheduleLoader(
        cache: cache,
        api: _api(
          todayMasses: const [],
          massTimes: [DateTime(2026, 9, 11, 18, 30)],
        ),
      );
      final days = (await loader.refresh(_church, _today)).massesByDay;

      expect(days[1].map((m) => m.time), [DateTime(2026, 9, 11, 18, 30)]);
      final stored = await cache.getMassesForChurch(38);
      expect(stored.single.apiMassId, 129807);
    });

    test('shows and stores a mass once when the API repeats it', () async {
      final morning = DateTime(2026, 9, 11, 7, 0);
      final evening = DateTime(2026, 9, 11, 18, 0);
      final loader = ChurchScheduleLoader(
        cache: cache,
        api: _api(
          todayMasses: const [],
          massTimes: [morning, morning, morning, evening, evening, evening],
        ),
      );

      final days = (await loader.refresh(_church, _today)).massesByDay;

      expect(days[1].map((m) => m.time), [morning, evening]);
      expect(await cache.getMassesForChurch(38), hasLength(2));
    });

    test('writes the church response into the cache', () async {
      final loader = ChurchScheduleLoader(
        cache: cache,
        api: _api(massTimes: [DateTime(2026, 9, 10, 18, 30)]),
      );

      await loader.refresh(_church, _today);

      final stored = (await cache.getChurch(38))!;
      expect(stored.email, 'iroda.belvarosiplebania@gmail.com');
      expect(stored.photos, hasLength(7));
      expect(stored.adorations, hasLength(5));
      expect(stored.localSyncedAt, isNotNull);
    });

    test('keeps the cached masses when the API cannot be reached', () async {
      await cache.replaceMassesForChurch(38, [
        _mass(DateTime(2026, 9, 10, 9, 0), 'Bootstrap mise'),
      ]);

      final loader = ChurchScheduleLoader(
        cache: cache,
        api: _api(failure: ApiFailure.noConnection),
      );
      final page = await loader.refresh(_church, _today);

      expect(page.massesByDay[0].map((m) => m.info), ['Bootstrap mise']);
      expect(page.freshDays, 0);
      expect(page.failure, ApiFailure.noConnection);
    });

    test(
      'keeps the cached masses when the server answers with an error',
      () async {
        await cache.replaceMassesForChurch(38, [
          _mass(DateTime(2026, 9, 10, 9, 0), 'Bootstrap mise'),
        ]);

        final loader = ChurchScheduleLoader(
          cache: cache,
          api: _api(failure: ApiFailure.serverError),
        );
        final page = await loader.refresh(_church, _today);

        expect(page.massesByDay[0].map((m) => m.info), ['Bootstrap mise']);
        expect(page.freshDays, 0);
        expect(page.failure, ApiFailure.serverError);
      },
    );

    test('empties the stored schedule when the API answers with none', () async {
      await cache.replaceMassesForChurch(38, [
        _mass(DateTime(2026, 9, 10, 9, 0), 'Bootstrap mise'),
      ]);

      final loader = ChurchScheduleLoader(
        cache: cache,
        api: _api(todayMasses: const []),
      );
      final page = await loader.refresh(_church, _today);

      // A successful empty answer says the church holds no mass in the window.
      expect(page.massesByDay.expand((day) => day), isEmpty);
      expect(page.freshDays, ChurchScheduleLoader.scheduleDays);
      expect(page.failure, isNull);
    });

    test(
      'asks for the church in the ids form, with the full response',
      () async {
        final bodies = <String, Object?>{};
        final api = MiserendApiClient(
          client: MockClient((request) async {
            bodies[request.url.path] = jsonDecode(request.body);
            if (request.url.path.endsWith('nearbymasses')) {
              return http.Response.bytes(
                utf8.encode(_nearbyMassesAt(const [])),
                200,
              );
            }
            return _churchResponse();
          }),
        );

        await ChurchScheduleLoader(
          cache: cache,
          api: api,
        ).refresh(_church, _today);

        expect(bodies['/api/v4/church'], {
          'ids': [38],
          'response_length': 'full',
        });
      },
    );

    test('skips the masses call for a church with no coordinates', () async {
      var askedForMasses = false;
      final api = MiserendApiClient(
        client: MockClient((request) async {
          if (request.url.path.endsWith('nearbymasses')) {
            askedForMasses = true;
          }
          return _churchResponse();
        }),
      );

      final noCoordinates = Church(
        id: 38,
        name: 'Templom',
        commonName: null,
        isGreek: false,
        lat: null,
        lon: null,
        address: null,
        city: null,
        country: null,
        county: null,
        street: null,
        gettingThere: null,
        imageUrl: null,
      );

      await ChurchScheduleLoader(
        cache: cache,
        api: api,
      ).refresh(noCoordinates, _today);

      expect(askedForMasses, isFalse);
      expect(await cache.getChurch(38), isNotNull);
    });

    test('an answer cut off at the limit is fresh only to the church\'s last '
        'day in it', () async {
      // 40 items of a nearer church, then the church's own 60, up to 09.15.
      final times = [
        for (var day = 10; day <= 15; day++)
          for (var hour = 8; hour < 18; hour++) DateTime(2026, 9, day, hour),
      ];
      final loader = ChurchScheduleLoader(
        cache: cache,
        api: _api(massTimes: times, nearer: 40),
      );

      final page = await loader.refresh(_church, _today);

      expect(page.freshDays, 6);
      expect(page.massesByDay[5], hasLength(10));
    });

    test(
      'an answer a nearer church fills to the limit is fresh on no day',
      () async {
        final loader = ChurchScheduleLoader(
          cache: cache,
          api: _api(nearer: 100),
        );

        final page = await loader.refresh(_church, _today);

        expect(page.freshDays, 0);
        expect(page.failure, isNull);
      },
    );

    test('a cut-off answer keeps what the cache holds past the cut-off, and '
        'replaces what lies before it', () async {
      await cache.replaceMassesForChurch(38, [
        _mass(DateTime(2026, 9, 11, 9, 0), 'Régi holnapi mise'),
        _mass(DateTime(2026, 9, 12, 9, 0), 'Bootstrap mise'),
      ]);
      final loader = ChurchScheduleLoader(
        cache: cache,
        api: _api(massTimes: [DateTime(2026, 9, 11, 18, 0)], nearer: 99),
      );

      final page = await loader.refresh(_church, _today);

      expect(page.freshDays, 2);
      expect(page.massesByDay[1].map((m) => m.info), ['Szentmise']);
      expect(page.massesByDay[2].map((m) => m.info), ['Bootstrap mise']);
    });

    test('a successful refresh carries no failure', () async {
      final loader = ChurchScheduleLoader(
        cache: cache,
        api: _api(massTimes: [DateTime(2026, 9, 10, 18, 30)]),
      );

      final page = await loader.refresh(_church, _today);

      expect(page.freshDays, ChurchScheduleLoader.scheduleDays);
      expect(page.failure, isNull);
    });

    group('today', () {
      // The basilica on 2026-10-16, moved to the test's day: two masses at
      // six, the list answer telling them apart and the schedule not.
      final evening = DateTime(2026, 9, 10, 18, 0);
      final tomorrow = DateTime(2026, 9, 11, 18, 0);
      const plain = 'Római katolikus Szentmise';
      const english =
          'Római katolikus Szentmise angol nyelven, Csendes '
          '(Mária-kápolnában)';
      const todayMasses = [
        {'idopont': '2026-09-10 18:00:00', 'informacio': plain},
        {'idopont': '2026-09-10 18:00:00', 'informacio': english},
      ];

      test(
        'is the church answer\'s, the schedule fills the days after',
        () async {
          final loader = ChurchScheduleLoader(
            cache: cache,
            api: _api(
              todayMasses: todayMasses,
              massTimes: [evening, evening, tomorrow],
              massIds: [98061, 98066, 98061],
            ),
          );

          final days = (await loader.refresh(_church, _today)).massesByDay;

          expect(days[0].map((m) => (m.time, m.info, m.source)), [
            (evening, plain, MassSource.dailyList),
            (evening, english, MassSource.dailyList),
          ]);
          expect(days[1].map((m) => (m.time, m.info, m.source)), [
            (tomorrow, 'Szentmise', MassSource.nearbyMasses),
          ]);
        },
      );

      test('is the schedule\'s when the church call fails', () async {
        final loader = ChurchScheduleLoader(
          cache: cache,
          api: _api(
            churchFailure: ApiFailure.serverError,
            massTimes: [evening, evening],
            massIds: [98061, 98066],
          ),
        );

        final days = (await loader.refresh(_church, _today)).massesByDay;

        expect(days[0].map((m) => (m.info, m.source)), [
          ('Szentmise', MassSource.nearbyMasses),
          ('Szentmise', MassSource.nearbyMasses),
        ]);
      });

      test('is empty when the church answer holds none, whatever the '
          'schedule says', () async {
        final loader = ChurchScheduleLoader(
          cache: cache,
          api: _api(todayMasses: const [], massTimes: [evening, tomorrow]),
        );

        final days = (await loader.refresh(_church, _today)).massesByDay;

        expect(days[0], isEmpty);
        expect(days[1].map((m) => m.time), [tomorrow]);
      });
    });

    test('reports confession from the API answer', () async {
      final loader = ChurchScheduleLoader(
        cache: cache,
        api: _api(massTimes: const [], confession: true),
      );

      expect((await loader.refresh(_church, _today)).confessionLive, isTrue);
    });
  });

  group('confession is never served from the cache', () {
    test('a stored true does not light the tile', () async {
      // Write a row that says confession is on, the way an earlier visit would.
      await ChurchScheduleLoader(
        cache: cache,
        api: _api(confession: true),
      ).refresh(_church, _today);
      expect((await cache.getChurch(38))!.hasConfession, isTrue);

      // A later visit reading only the cache must not repeat the claim: the
      // value is a momentary switch reading, not an attribute of the church.
      final cached = await ChurchScheduleLoader(
        cache: cache,
        api: _api(),
      ).loadCached(38, _today);

      expect(cached.church, isNotNull);
      expect(cached.confessionLive, isFalse);
    });
  });

  group('how old the data is', () {
    test('is when this phone last synced the church', () async {
      await ChurchScheduleLoader(
        cache: cache,
        api: _api(),
      ).refresh(_church, _today);
      final synced = (await cache.getChurch(38))!.localSyncedAt!;

      final page = await ChurchScheduleLoader(
        cache: cache,
        api: _api(failure: ApiFailure.noConnection),
      ).refresh(_church, _today);

      expect(page.dataAsOf, synced);
    });

    test('is the bootstrap import for a church never synced', () async {
      await cache.importChurches([
        BootstrapImporter.churchFromLegacyRow({'tid': 38, 'nev': 'Templom'}),
      ], const []);
      await cache.setBootstrappedAt(DateTime(2026, 8, 1, 10, 0));

      final page = await ChurchScheduleLoader(
        cache: cache,
        api: _api(),
      ).loadCached(38, _today);

      expect(page.dataAsOf, DateTime(2026, 8, 1, 10, 0));
    });
  });

  group('a church miserend.hu no longer has', () {
    MiserendApiClient goneApi(List<String> paths) => MiserendApiClient(
      client: MockClient((request) async {
        paths.add(request.url.path);
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'templomok': [],
              'hianyzo': [38],
              'error': 0,
            }),
          ),
          200,
        );
      }),
    );

    test('is deleted from the cache and the favorites, and says so', () async {
      await cache.importChurches(
        [
          BootstrapImporter.churchFromLegacyRow({'tid': 38, 'nev': 'Templom'}),
        ],
        [_mass(DateTime(2026, 9, 10, 9, 0), 'Bootstrap mise')],
      );
      final gone = <int>[];
      final paths = <String>[];

      final page = await ChurchScheduleLoader(
        cache: cache,
        api: goneApi(paths),
        onChurchesGone: (ids) async => gone.addAll(ids),
      ).refresh(_church, _today);

      expect(page.churchGone, isTrue);
      expect(page.failure, isNull);
      expect(page.massesByDay.expand((day) => day), isEmpty);
      expect(await cache.getChurch(38), isNull);
      expect(await cache.getMassesForChurch(38), isEmpty);
      expect(gone, [38]);
      expect(paths, [
        '/api/v4/church',
      ], reason: 'there is no schedule left to ask for');
    });

    test('a church that is still there is not gone', () async {
      final page = await ChurchScheduleLoader(
        cache: cache,
        api: _api(),
      ).refresh(_church, _today);

      expect(page.churchGone, isFalse);
    });
  });
}
