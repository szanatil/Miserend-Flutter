import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/api/api_result.dart';
import 'package:miserend/church_details/church_details_page.dart';
import 'package:miserend/church_details/church_page_data.dart';
import 'package:miserend/church_details/church_schedule_loader.dart';
import 'package:miserend/database/cache/adoration.dart';
import 'package:miserend/database/cache/cached_mass.dart';
import 'package:miserend/database/cache/church_details.dart';
import 'package:miserend/database/church.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/widgets/offline_notice.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

DateTime _todayAt(int hour, int minute) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, hour, minute);
}

ChurchDetails _details({
  String? description,
  String? email,
  List<String> links = const [],
  List<String> languages = const [],
  List<Adoration> adorations = const [],
  bool? hasConfession,
  Map<String, dynamic>? accessibility,
}) {
  return ChurchDetails(
    id: 38,
    name: 'Belvárosi Nagyboldogasszony-templom',
    commonName: 'Főplébániatemplom',
    names: const [],
    alternativeNames: const [],
    country: 'Magyarország',
    diocese: null,
    county: 'Budapest',
    city: 'Budapest V. kerület',
    street: 'Március 15. tér',
    gettingThere: null,
    parish: null,
    description: description,
    accessibility: accessibility,
    email: email,
    links: links,
    languages: languages,
    massScheduleNote: null,
    adorations: adorations,
    hasConfession: hasConfession,
    communities: const [],
    lat: 47.492233,
    lon: 19.0522943,
    photos: const [],
    updatedAt: null,
    localSyncedAt: null,
    isGreek: false,
  );
}

List<List<CachedMass>> _emptyDays() =>
    List.generate(ChurchScheduleLoader.scheduleDays, (_) => <CachedMass>[]);

List<List<CachedMass>> _scheduleWith(DateTime time, {String? info}) {
  final days = _emptyDays();
  days[0].add(CachedMass(
    id: null,
    apiMassId: null,
    churchId: 38,
    time: time,
    info: info ?? 'Római katolikus Szentmise',
    source: MassSource.nearbyMasses,
  ));
  return days;
}

ChurchPageData _page(
  List<List<CachedMass>> masses, {
  ChurchDetails? church,
  bool scheduleIsFresh = false,
  bool confessionLive = false,
  ApiFailure? failure,
  DateTime? dataAsOf,
}) {
  return ChurchPageData(
    church: church,
    massesByDay: masses,
    scheduleIsFresh: scheduleIsFresh,
    confessionLive: confessionLive,
    failure: failure,
    dataAsOf: dataAsOf,
  );
}

/// Stands in for the real loader so that the page can be pumped without a
/// database or a network call. [answerApi] releases the refresh, so a test can
/// look at the page while the API call is still outstanding.
class _FakeLoader extends ChurchScheduleLoader {
  _FakeLoader({required this.cached, required this.refreshed});

  final ChurchPageData cached;
  final ChurchPageData refreshed;
  final Completer<void> _apiAnswered = Completer<void>();

  void answerApi() => _apiAnswered.complete();

  @override
  Future<ChurchPageData> loadCached(int churchId, DateTime today) async =>
      cached;

  @override
  Future<ChurchPageData> refresh(Church church, DateTime today) async {
    await _apiAnswered.future;
    return refreshed;
  }
}

void main() {
  // FavoritesService opens a database from its constructor, so the factory has
  // to exist even though this test never reads a favorite.
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Built once, in the real async zone, and shared by value. Constructing one
  // per test leaves sqflite's lock timer pending inside testWidgets' fake
  // clock, which fails the test that happens to be running when it fires.
  late FavoritesService favorites;

  setUpAll(() async {
    favorites = FavoritesService();
    for (var i = 0; i < 400 && !favorites.loaded; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  });

  Future<void> pumpPage(WidgetTester tester, ChurchScheduleLoader loader) async {
    // Tall enough for the lazy ListView to build every section, so a test can
    // assert that one is absent rather than merely off-screen.
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ChangeNotifierProvider<FavoritesService>.value(
      value: favorites,
      child: MaterialApp(
        home: ChurchDetailsPage(church: _church, loader: loader),
      ),
    ));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows the cached schedule while the API call is outstanding',
      (tester) async {
    final loader = _FakeLoader(
      cached: _page(_scheduleWith(_todayAt(9, 0))),
      refreshed: _page(_scheduleWith(_todayAt(18, 30))),
    );

    await pumpPage(tester, loader);

    expect(find.text('09:00'), findsWidgets);
    expect(find.text('18:30'), findsNothing);
  });

  testWidgets('shows the refreshed schedule once the API has answered',
      (tester) async {
    final loader = _FakeLoader(
      cached: _page(_scheduleWith(_todayAt(9, 0))),
      refreshed: _page(_scheduleWith(_todayAt(18, 30))),
    );

    await pumpPage(tester, loader);
    loader.answerApi();
    await tester.pump();
    await tester.pump();

    expect(find.text('18:30'), findsWidgets);
    expect(find.text('09:00'), findsNothing);
  });

  testWidgets('shows the church name', (tester) async {
    final empty = _page(_emptyDays());
    await pumpPage(tester, _FakeLoader(cached: empty, refreshed: empty));

    expect(find.text('Belvárosi Nagyboldogasszony-templom'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty day without a response reads as missing data, not as '
      'no mass', (tester) async {
    final empty = _page(_emptyDays());
    await pumpPage(tester, _FakeLoader(cached: empty, refreshed: empty));

    // The two rows word it differently, and on a Sunday the "Most vasárnap"
    // row is not drawn at all because it would repeat "Ma".
    expect(find.text('Nincs adat a mai miserendről'), findsOneWidget);
    expect(find.text('Ezen a napon nincs mise'), findsNothing);
    expect(find.text('Nincs adat erről a napról'),
        DateTime.now().weekday == DateTime.sunday ? findsNothing : findsOneWidget);
  });

  testWidgets('an empty day with a response reads as no mass', (tester) async {
    final loader = _FakeLoader(
      cached: _page(_emptyDays()),
      refreshed: _page(_emptyDays(), scheduleIsFresh: true),
    );

    await pumpPage(tester, loader);
    loader.answerApi();
    await tester.pump();
    await tester.pump();

    expect(find.text('Ezen a napon nincs mise'), findsWidgets);
    expect(find.text('Nincs adat a mai miserendről'), findsNothing);
  });

  testWidgets('the day strip skips days with no masses', (tester) async {
    final masses = _emptyDays();
    masses[3].add(CachedMass(
      id: null,
      apiMassId: null,
      churchId: 38,
      time: _todayAt(7, 30).add(const Duration(days: 3)),
      info: null,
      source: MassSource.nearbyMasses,
    ));
    final data = _page(masses, scheduleIsFresh: true);

    await pumpPage(tester, _FakeLoader(cached: data, refreshed: data));

    // One card, for the only day that has anything.
    expect(find.text('07:30'), findsOneWidget);
    expect(find.byType(Card), findsWidgets);
  });

  testWidgets('no confession tile without a live response', (tester) async {
    // The cache says yes, but a cached value is a stale switch reading.
    final cached = _page(_emptyDays(),
        church: _details(hasConfession: true), confessionLive: false);
    await pumpPage(tester, _FakeLoader(cached: cached, refreshed: cached));

    expect(find.text('Most gyóntatnak!'), findsNothing);
  });

  testWidgets('confession tile appears for a live response', (tester) async {
    final loader = _FakeLoader(
      cached: _page(_emptyDays()),
      refreshed: _page(_emptyDays(),
          church: _details(hasConfession: true), confessionLive: true),
    );

    await pumpPage(tester, loader);
    loader.answerApi();
    await tester.pump();
    await tester.pump();

    expect(find.text('Most gyóntatnak!'), findsOneWidget);
  });

  testWidgets('sections with no data are absent entirely', (tester) async {
    final data = _page(_emptyDays(), church: _details());
    await pumpPage(tester, _FakeLoader(cached: data, refreshed: data));

    expect(find.text('Leírás'), findsNothing);
    expect(find.text('Elérhetőség'), findsNothing);
    expect(find.text('Nyelvek'), findsNothing);
    expect(find.text('Akadálymentesség'), findsNothing);
    expect(find.text('Szentségimádás'), findsNothing);
  });

  testWidgets('a Hungarian-only language list earns no tile', (tester) async {
    final data = _page(_emptyDays(), church: _details(languages: ['hu']));
    await pumpPage(tester, _FakeLoader(cached: data, refreshed: data));

    expect(find.text('Nyelvek'), findsNothing);
  });

  testWidgets('languages are drawn as flags, named for screen readers',
      (tester) async {
    final data =
        _page(_emptyDays(), church: _details(languages: ['hu', 'en', 'ua']));
    await pumpPage(tester, _FakeLoader(cached: data, refreshed: data));

    expect(find.text('Nyelvek'), findsOneWidget);
    // A flag each, including the Hungarian one: dropping it would suggest
    // there is no Hungarian mass.
    expect(find.byType(SvgPicture), findsNWidgets(3));
    // The code is never shown as text, but the language name is readable.
    expect(find.text('ua'), findsNothing);
    expect(find.text('UA'), findsNothing);
    expect(find.bySemanticsLabel('ukrán'), findsOneWidget);
  });

  testWidgets('the Vatican flag stands for Latin, not for a country',
      (tester) async {
    // `va` and `tl` are miserend's own vocabulary, not ISO 639; reading them
    // as language codes is what used to render "VA" and "TL" as text.
    final data =
        _page(_emptyDays(), church: _details(languages: ['hu', 'va', 'tl']));
    await pumpPage(tester, _FakeLoader(cached: data, refreshed: data));

    expect(find.text('VA'), findsNothing);
    expect(find.text('TL'), findsNothing);
    expect(find.bySemanticsLabel('latin'), findsOneWidget);
    expect(find.bySemanticsLabel('tagalog'), findsOneWidget);
  });

  testWidgets('a code with no flag falls back to text rather than vanishing',
      (tester) async {
    final data =
        _page(_emptyDays(), church: _details(languages: ['hu', 'zz']));
    await pumpPage(tester, _FakeLoader(cached: data, refreshed: data));

    expect(find.text('ZZ'), findsOneWidget);
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('an all-day adoration window is named, not printed as a range',
      (tester) async {
    final start = _todayAt(0, 0);
    final data = _page(
      _emptyDays(),
      church: _details(adorations: [
        Adoration(
          start: start,
          end: _todayAt(23, 59),
          kind: 'csendes',
          info: null,
        ),
      ]),
    );

    await pumpPage(tester, _FakeLoader(cached: data, refreshed: data));

    expect(find.text('Szentségimádás'), findsOneWidget);
    expect(find.text('Egész nap · csendes'), findsOneWidget);
    expect(find.text('00:00 – 23:59 · csendes'), findsNothing);
  });

  testWidgets('accessibility states a "no" plainly', (tester) async {
    final data = _page(_emptyDays(),
        church: _details(accessibility: {'wheelchair': 'no'}));
    await pumpPage(tester, _FakeLoader(cached: data, refreshed: data));

    expect(find.text('Kerekesszékkel nem megközelíthető'), findsOneWidget);
  });

  group('marking data that is not live', () {
    Future<void> refreshWith(WidgetTester tester, ChurchPageData refreshed) async {
      final loader = _FakeLoader(
        cached: _page(_scheduleWith(_todayAt(9, 0))),
        refreshed: refreshed,
      );
      await pumpPage(tester, loader);
      loader.answerApi();
      await tester.pump();
      await tester.pump();
    }

    Color? bannerColor(WidgetTester tester) => tester
        .widget<Material>(find
            .descendant(
                of: find.byType(OfflineBanner), matching: find.byType(Material))
            .first)
        .color;

    testWidgets('nothing is marked while the API call is outstanding',
        (tester) async {
      final loader = _FakeLoader(
        cached: _page(_scheduleWith(_todayAt(9, 0))),
        refreshed: _page(_scheduleWith(_todayAt(9, 0)),
            failure: ApiFailure.noConnection),
      );

      await pumpPage(tester, loader);

      expect(find.byType(OfflineBanner), findsNothing);
    });

    testWidgets('nothing is marked after a successful refresh', (tester) async {
      await refreshWith(
          tester, _page(_scheduleWith(_todayAt(9, 0)), scheduleIsFresh: true));

      expect(find.byType(OfflineBanner), findsNothing);
    });

    testWidgets('no connection puts the lists\' banner above the page, '
        'untinted', (tester) async {
      await refreshWith(
          tester,
          _page(_scheduleWith(_todayAt(9, 0)),
              failure: ApiFailure.noConnection));

      expect(find.byType(OfflineBanner), findsOneWidget);
      expect(find.byType(OfflineInfoButton), findsOneWidget);
      expect(bannerColor(tester), isNot(OfflineNotice.serverErrorTint));
      expect(tester.getTopLeft(find.byType(OfflineBanner)).dy,
          lessThan(tester.getTopLeft(find.text('Ma')).dy));
    });

    testWidgets('a server error tints the banner, not the masses card',
        (tester) async {
      await refreshWith(
          tester,
          _page(_scheduleWith(_todayAt(9, 0)),
              failure: ApiFailure.serverError));

      expect(bannerColor(tester), OfflineNotice.serverErrorTint);
      expect(find.byType(OfflineInfoButton), findsOneWidget);
      final massCard = tester.widget<Card>(find
          .ancestor(of: find.text('Ma'), matching: find.byType(Card))
          .first);
      expect(massCard.color, isNull);
    });

    testWidgets('the (i) tells how old the data is and what to do',
        (tester) async {
      await refreshWith(
          tester,
          _page(_scheduleWith(_todayAt(9, 0)),
              failure: ApiFailure.noConnection,
              dataAsOf: DateTime(2026, 8, 1, 10, 0)));

      await tester.tap(find.byType(OfflineInfoButton));
      await tester.pumpAndSettle();

      expect(
          find.text('Az adatok a telefonon tárolt, 2026. 08. 01-i állapotot '
              'mutatják. Frissítéshez kapcsold be az adatkapcsolatot, vagy '
              'ellenőrizd, hogy a Miserend használhat-e mobilnetet a telefon '
              'beállításaiban, majd nyisd meg újra a templomot.'),
          findsOneWidget);
    });

    testWidgets('the (i) of a server error says miserend.hu is unavailable',
        (tester) async {
      await refreshWith(
          tester,
          _page(_scheduleWith(_todayAt(9, 0)),
              failure: ApiFailure.serverError,
              dataAsOf: DateTime(2026, 8, 1, 10, 0)));

      await tester.tap(find.byType(OfflineInfoButton));
      await tester.pumpAndSettle();

      expect(
          find.text('A miserend.hu jelenleg nem elérhető, az adatok '
              '2026. 08. 01-i állapotot mutatnak.'),
          findsOneWidget);
    });
  });

  testWidgets('a church no longer on miserend.hu says so in place of the '
      'schedule, and the page stays open', (tester) async {
    final loader = _FakeLoader(
      cached: _page(_scheduleWith(_todayAt(9, 0)), church: _details()),
      refreshed: ChurchPageData(
        church: null,
        massesByDay: _emptyDays(),
        scheduleIsFresh: false,
        confessionLive: false,
        churchGone: true,
      ),
    );

    await pumpPage(tester, loader);
    loader.answerApi();
    await tester.pump();
    await tester.pump();

    expect(find.text('Ez a templom már nem szerepel a miserend.hu-n.'),
        findsOneWidget);
    expect(find.text('09:00'), findsNothing);
    expect(find.text('Nincs adat a mai miserendről'), findsNothing);
    expect(find.text('Most vasárnap'), findsNothing);
    expect(find.byType(ChurchDetailsPage), findsOneWidget);
    // The name the page was opened with stays readable.
    expect(find.text('Belvárosi Nagyboldogasszony-templom'), findsOneWidget);
  });
}
