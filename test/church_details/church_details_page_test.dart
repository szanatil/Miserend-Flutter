import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/api/api_result.dart';
import 'package:miserend/church_details/church_details_page.dart';
import 'package:miserend/church_details/church_page_data.dart';
import 'package:miserend/church_details/church_schedule_loader.dart';
import 'package:miserend/church_details/report_problem_page.dart';
import 'package:miserend/church_details/widgets/contact_card.dart';
import 'package:miserend/church_details/widgets/photo_header.dart';
import 'package:miserend/database/cache/adoration.dart';
import 'package:miserend/database/cache/cached_mass.dart';
import 'package:miserend/database/cache/church_details.dart';
import 'package:miserend/database/church.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/theme/miserend_colors.dart';
import 'package:miserend/theme/miserend_theme.dart';
import 'package:miserend/theme/tokens.dart';
import 'package:miserend/widgets/miserend_map.dart';
import 'package:miserend/widgets/offline_notice.dart';
import 'package:miserend/widgets/section_card.dart';
import 'package:miserend/widgets/stale_data_retry.dart';
import 'package:miserend/widgets/time_chip.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database/fake_favorites_service.dart';
import '../theme/theme_harness.dart';

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

/// Long enough for [ExpandableInfoTile] to collapse it even on a wide page.
final String _longText = List.filled(
  12,
  'A templom a város legrégebbi épülete, többször átépítették.',
).join(' ');

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
  days[0].add(
    CachedMass(
      id: null,
      apiMassId: null,
      churchId: 38,
      time: time,
      info: info ?? 'Római katolikus Szentmise',
      source: MassSource.nearbyMasses,
    ),
  );
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

  /// Not final: a test moves it on, to stand for the connection coming back
  /// between one retry and the next.
  ChurchPageData refreshed;

  final Completer<void> _apiAnswered = Completer<void>();

  /// How many times the API has been asked.
  int refreshes = 0;

  void answerApi() => _apiAnswered.complete();

  @override
  Future<ChurchPageData> loadCached(int churchId, DateTime today) async =>
      cached;

  @override
  Future<ChurchPageData> refresh(Church church, DateTime today) async {
    refreshes++;
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

  Future<void> pumpPage(
    WidgetTester tester,
    ChurchScheduleLoader loader, {
    DateTime Function() clock = DateTime.now,
    Brightness brightness = Brightness.light,
    double width = 1000,
    double textScale = 1,
    double height = 4000,
    bool pushed = false,
    FavoritesService? favoritesService,
  }) async {
    // Tall enough for the lazy ListView to build every section, so a test can
    // assert that one is absent rather than merely off-screen.
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      ChangeNotifierProvider<FavoritesService>.value(
        value: favoritesService ?? favorites,
        child: MaterialApp(
          theme: miserendTheme(brightness),
          home:
              pushed
                  ? Builder(
                    builder:
                        (context) => TextButton(
                          onPressed:
                              () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder:
                                      (_) => ChurchDetailsPage(
                                        church: _church,
                                        loader: loader,
                                        clock: clock,
                                      ),
                                ),
                              ),
                          child: const Text('Megnyitás'),
                        ),
                  )
                  : ChurchDetailsPage(
                    church: _church,
                    loader: loader,
                    clock: clock,
                  ),
        ),
      ),
    );
    if (pushed) {
      await tester.tap(find.text('Megnyitás'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows the cached schedule while the API call is outstanding', (
    tester,
  ) async {
    final loader = _FakeLoader(
      cached: _page(_scheduleWith(_todayAt(9, 0))),
      refreshed: _page(_scheduleWith(_todayAt(18, 30))),
    );

    await pumpPage(tester, loader);

    expect(find.text('9:00'), findsWidgets);
    expect(find.text('18:30'), findsNothing);
  });

  testWidgets('shows the refreshed schedule once the API has answered', (
    tester,
  ) async {
    final loader = _FakeLoader(
      cached: _page(_scheduleWith(_todayAt(9, 0))),
      refreshed: _page(_scheduleWith(_todayAt(18, 30))),
    );

    await pumpPage(tester, loader);
    loader.answerApi();
    await tester.pump();
    await tester.pump();

    expect(find.text('18:30'), findsWidgets);
    expect(find.text('9:00'), findsNothing);
  });

  testWidgets('a mass going on now has its chip in the filled orange, a '
      'later one not (KO3)', (tester) async {
    final page = _page(_scheduleWith(_todayAt(9, 0)));
    await pumpPage(
      tester,
      _FakeLoader(cached: page, refreshed: page),
      clock: () => _todayAt(9, 5),
    );

    final chips = tester.widgetList<TimeChip>(
      find.ancestor(of: find.text('9:00'), matching: find.byType(TimeChip)),
    );
    expect(chips.first.ongoing, isTrue);

    await pumpPage(
      tester,
      _FakeLoader(cached: page, refreshed: page),
      clock: () => _todayAt(8, 59),
    );

    expect(
      tester
          .widgetList<TimeChip>(
            find.ancestor(
              of: find.text('9:00'),
              matching: find.byType(TimeChip),
            ),
          )
          .any((chip) => chip.ongoing),
      isFalse,
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets('in $brightness, the page is the theme\'s surface, not a '
        'fixed grey (SZ5)', (tester) async {
      final page = _page(_emptyDays());
      await pumpPage(
        tester,
        _FakeLoader(cached: page, refreshed: page),
        brightness: brightness,
      );

      final ground = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(Scaffold),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(ground.color, miserendTheme(brightness).colorScheme.surface);
    });
  }

  testWidgets('the day headings are section titles, titleMedium w600 (TI2)', (
    tester,
  ) async {
    // A Wednesday, so that both "Ma" and "Most vasárnap" are shown.
    final page = _page(_emptyDays());
    await pumpPage(
      tester,
      _FakeLoader(cached: page, refreshed: page),
      clock: () => DateTime(2026, 10, 7, 9),
    );

    for (final heading in ['Ma', 'Most vasárnap']) {
      final titleMedium =
          Theme.of(tester.element(find.text(heading))).textTheme.titleMedium!;
      final style = tester.widget<Text>(find.text(heading)).style!;
      expect(style.fontSize, titleMedium.fontSize, reason: heading);
      expect(style.fontWeight, FontWeight.w600, reason: heading);
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('in $brightness, an unselected favourite is an outline in the '
        'secondary colour, not the button\'s primary (IK4)', (tester) async {
      final page = _page(_emptyDays());
      await pumpPage(
        tester,
        _FakeLoader(cached: page, refreshed: page),
        brightness: brightness,
      );

      expect(
        tester.widget<Icon>(find.byIcon(Icons.favorite_border_rounded)).color,
        schemeOf(brightness).onSurfaceVariant,
      );
    });
  }

  testWidgets('the favourite is filled only while selected: '
      'favorite_rounded, otherwise favorite_border_rounded (IK2)', (
    tester,
  ) async {
    final page = _page(_emptyDays());
    await pumpPage(
      tester,
      _FakeLoader(cached: page, refreshed: page),
      favoritesService: FakeFavoritesService([]),
    );

    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);

    await tester.tap(find.text('Kedvencekhez'));
    await tester.pump();

    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
  });

  testWidgets('the action buttons\' icons are regular icons, 24 (IK3)', (
    tester,
  ) async {
    final page = _page(_emptyDays());
    await pumpPage(tester, _FakeLoader(cached: page, refreshed: page));

    for (final icon in [
      Icons.favorite_border_rounded,
      Icons.error_outline_rounded,
    ]) {
      expect(tester.getSize(find.byIcon(icon)), const Size(24, 24));
    }
  });

  group('the back button over the photo (KO19)', () {
    // The back button is the platform's own (PL2), so each case runs on both.
    const platforms = TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    });

    SliverAppBar appBar(WidgetTester tester) =>
        tester.widget<SliverAppBar>(find.byType(SliverAppBar));

    for (final brightness in Brightness.values) {
      testWidgets('in $brightness, it stands on a dark disc in onPhoto, '
          'under light status bar icons', (tester) async {
        final page = _page(_scheduleWith(_todayAt(9, 0)));
        await pumpPage(
          tester,
          _FakeLoader(cached: page, refreshed: page),
          brightness: brightness,
          pushed: true,
        );
        final colors = miserendColorsOf(brightness);

        final style = tester.widget<BackButton>(find.byType(BackButton)).style!;
        expect(style.backgroundColor!.resolve({}), colors.photoScrim);
        expect(style.foregroundColor!.resolve({}), colors.onPhoto);
        expect(
          appBar(tester).systemOverlayStyle!.statusBarIconBrightness,
          Brightness.light,
        );
      }, variant: platforms);
    }

    testWidgets('once the header has collapsed, it is the title bar\'s own '
        'again', (tester) async {
      final page = _page(_scheduleWith(_todayAt(9, 0)));
      await pumpPage(
        tester,
        _FakeLoader(cached: page, refreshed: page),
        height: 800,
        pushed: true,
      );

      await tester.drag(find.text('Hibajelentés'), const Offset(0, -600));
      await tester.pump();

      expect(appBar(tester).leading, isNull);
      expect(appBar(tester).systemOverlayStyle, isNull);
      expect(find.byType(BackButton), findsOneWidget);
    }, variant: platforms);

    testWidgets('in a wide window, where the header is taller, it stays on '
        'the photo until that header has collapsed', (tester) async {
      final page = _page(_scheduleWith(_todayAt(9, 0)));
      await pumpPage(
        tester,
        _FakeLoader(cached: page, refreshed: page),
        width: 1500,
        height: 1000,
        pushed: true,
      );

      // The header is 500 tall: 300 is past a 200 header's collapse, not
      // past this one's.
      await tester.drag(find.text('Hibajelentés'), const Offset(0, -300));
      await tester.pump();
      expect(appBar(tester).leading, isNotNull);
      expect(appBar(tester).systemOverlayStyle, SystemUiOverlayStyle.light);

      await tester.drag(find.text('Hibajelentés'), const Offset(0, -300));
      await tester.pump();
      expect(appBar(tester).leading, isNull);
      expect(appBar(tester).systemOverlayStyle, isNull);
    }, variant: platforms);

    testWidgets('with nowhere to go back to, there is no back button', (
      tester,
    ) async {
      final page = _page(_emptyDays());
      await pumpPage(tester, _FakeLoader(cached: page, refreshed: page));

      expect(find.byType(BackButton), findsNothing);
    }, variant: platforms);
  });

  group('the photo header\'s height (KO19)', () {
    double photoHeight(WidgetTester tester) =>
        tester.getSize(find.byType(ChurchPhotoHeader)).height;

    testWidgets('on a phone it is 16:9 to the width', (tester) async {
      final page = _page(_emptyDays());
      await pumpPage(
        tester,
        _FakeLoader(cached: page, refreshed: page),
        width: 360,
        height: 800,
      );

      expect(photoHeight(tester), 360 * 9 / 16);
    });

    testWidgets('in a wide window it is at most half the height', (
      tester,
    ) async {
      final page = _page(_emptyDays());
      await pumpPage(
        tester,
        _FakeLoader(cached: page, refreshed: page),
        width: 1500,
        height: 1000,
      );

      expect(photoHeight(tester), 500);
    });

    testWidgets('follows the window when it is resized', (tester) async {
      final page = _page(_emptyDays());
      await pumpPage(
        tester,
        _FakeLoader(cached: page, refreshed: page),
        width: 360,
        height: 1000,
      );

      tester.view.physicalSize = const Size(1500, 1000);
      await tester.pump();

      expect(photoHeight(tester), 500);
    });
  });

  group('fits (EH4)', () {
    for (final width in eh4Widths) {
      for (final textScale in eh4TextScales) {
        testWidgets('at $width dp and text scale $textScale', (tester) async {
          // Every tile with an icon, so their rows are measured too.
          final page = _page(
            _scheduleWith(_todayAt(9, 0)),
            church: _details(
              description: _longText,
              email: 'plebania@example.hu',
              links: ['https://www.example.hu/egy-hosszu-cim'],
              accessibility: {'wheelchair': 'limited'},
            ),
          );
          await pumpPage(
            tester,
            _FakeLoader(cached: page, refreshed: page),
            width: width,
            textScale: textScale,
          );

          expect(find.text('Hibajelentés'), findsOneWidget);
          expect(find.text('plebania@example.hu'), findsOneWidget);
          expect(find.text('Több'), findsOneWidget);
          expect(find.byIcon(Icons.accessible_rounded), findsOneWidget);
          expect(tester.takeException(), isNull);
        }, variant: eh4Platforms);
      }
    }
  });

  testWidgets('fits a phone on its side (EL5)', (tester) async {
    final page = _page(
      _scheduleWith(_todayAt(9, 0)),
      church: _details(description: _longText, email: 'plebania@example.hu'),
    );
    await pumpPage(
      tester,
      _FakeLoader(cached: page, refreshed: page),
      width: 640,
      height: 320,
      textScale: 2,
    );

    await tester.drag(find.byType(NestedScrollView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }, variant: eh4Platforms);

  testWidgets('on an $el3Width dp screen the photo fills the width and the '
      'sections are at most 640 wide, centred (EL3)', (tester) async {
    final page = _page(
      _scheduleWith(_todayAt(9, 0)),
      church: _details(email: 'plebania@example.hu'),
    );
    await pumpPage(
      tester,
      _FakeLoader(cached: page, refreshed: page),
      width: el3Width,
    );

    expect(tester.getRect(find.byType(ChurchPhotoHeader)).width, el3Width);
    expectCentredContent(tester, find.byType(SectionCard).first);
  });

  group('on a wide screen the sections stand in columns (EL3)', () {
    ChurchPageData full({bool adoration = true}) => _page(
      _scheduleWith(_todayAt(9, 0)),
      church: _details(
        description: _longText,
        email: 'plebania@example.hu',
        adorations: [
          if (adoration)
            Adoration(
              start: _todayAt(0, 0),
              end: _todayAt(23, 59),
              kind: 'csendes',
              info: null,
            ),
        ],
      ),
    );

    // The outermost: the masses' card holds a card of its own.
    Rect section(WidgetTester tester, String text) => tester.getRect(
      find
          .ancestor(of: find.text(text), matching: find.byType(SectionCard))
          .last,
    );

    /// How far apart the cards in [left] and [right] stand, without their
    /// side margins.
    double gapBetween(Rect left, Rect right) =>
        (right.left + Spacing.l) - (left.right - Spacing.l);

    testWidgets('three columns: the masses across all of them, then when, '
        'where and about, side by side, as far apart as down (TK2)', (
      tester,
    ) async {
      final page = full();
      await pumpPage(
        tester,
        _FakeLoader(cached: page, refreshed: page),
        width: threeColumnWidth,
      );

      expect(section(tester, '9:00').width, threeColumnWidth);
      final when = section(tester, 'Szentségimádás');
      final where = section(tester, 'Megközelítés');
      final about = section(tester, 'Leírás');
      expect([when.left, about.right], [0, threeColumnWidth]);
      expect(where.width, moreOrLessEquals(when.width));
      expect(about.width, moreOrLessEquals(when.width));
      expect(gapBetween(when, where), moreOrLessEquals(Spacing.s));
      expect(gapBetween(where, about), moreOrLessEquals(Spacing.s));
      expect([where.top, about.top], [when.top, when.top]);
    });

    testWidgets('two columns: when on the left, where on the right, and '
        'about under the shorter', (tester) async {
      final page = full();
      await pumpPage(
        tester,
        _FakeLoader(cached: page, refreshed: page),
        width: twoColumnWidth,
      );

      final when = section(tester, 'Szentségimádás');
      final where = section(tester, 'Megközelítés');
      final contact = tester.getRect(find.byType(ContactCard));
      final about = section(tester, 'Leírás');
      expect([when.left, where.right], [0, twoColumnWidth]);
      expect(gapBetween(when, where), Spacing.s);
      expect(where.top, when.top);
      final shorter = when.bottom <= contact.bottom ? when : contact;
      expect(about.topLeft, Offset(shorter.left, shorter.bottom));
    });

    testWidgets('a church with neither adoration nor confession leaves no '
        'empty column', (tester) async {
      final page = full(adoration: false);
      await pumpPage(
        tester,
        _FakeLoader(cached: page, refreshed: page),
        width: threeColumnWidth,
      );

      expect(find.text('Szentségimádás'), findsNothing);
      final where = section(tester, 'Megközelítés');
      final about = section(tester, 'Leírás');
      expect([where.left, about.right], [0, threeColumnWidth]);
      expect(about.width, where.width);
      expect(gapBetween(where, about), Spacing.s);
      expect(about.top, where.top);
    });

    testWidgets('follows the window when it is resized', (tester) async {
      final page = full();
      await pumpPage(
        tester,
        _FakeLoader(cached: page, refreshed: page),
        width: el3Width,
      );
      expect(
        section(tester, 'Megközelítés').left,
        section(tester, '9:00').left,
      );

      tester.view.physicalSize = const Size(threeColumnWidth, 4000);
      await tester.pump();
      expect(
        section(tester, 'Megközelítés').top,
        section(tester, 'Szentségimádás').top,
      );

      tester.view.physicalSize = const Size(el3Width, 4000);
      await tester.pump();
      expect(
        section(tester, 'Megközelítés').left,
        section(tester, '9:00').left,
      );
    });

    for (final brightness in Brightness.values) {
      for (final width in const [twoColumnWidth, threeColumnWidth]) {
        for (final textScale in eh4TextScales) {
          testWidgets('fits in $brightness at $width dp and text scale '
              '$textScale (EH3, EH4)', (tester) async {
            final page = full();
            await pumpPage(
              tester,
              _FakeLoader(cached: page, refreshed: page),
              brightness: brightness,
              width: width,
              textScale: textScale,
            );

            expect(find.text('Leírás'), findsOneWidget);
            expect(tester.takeException(), isNull);
          }, variant: eh4Platforms);
        }
      }
    }
  });

  testWidgets('shows the church name', (tester) async {
    final empty = _page(_emptyDays());
    await pumpPage(tester, _FakeLoader(cached: empty, refreshed: empty));

    expect(find.text('Belvárosi Nagyboldogasszony-templom'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'the header leaves the title\'s alignment to the platform (PL2)',
    (tester) async {
      final empty = _page(_emptyDays());
      await pumpPage(tester, _FakeLoader(cached: empty, refreshed: empty));

      expect(
        tester.widget<SliverAppBar>(find.byType(SliverAppBar)).centerTitle,
        isNull,
      );
      expect(
        tester
            .widget<FlexibleSpaceBar>(find.byType(FlexibleSpaceBar))
            .centerTitle,
        isNull,
      );
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets('an empty day without a response reads as missing data, not as '
      'no mass', (tester) async {
    final empty = _page(_emptyDays());
    await pumpPage(tester, _FakeLoader(cached: empty, refreshed: empty));

    // The two rows word it differently, and on a Sunday the "Most vasárnap"
    // row is not drawn at all because it would repeat "Ma".
    expect(find.text('Nincs adat a mai miserendről'), findsOneWidget);
    expect(find.text('Ezen a napon nincs mise'), findsNothing);
    expect(
      find.text('Nincs adat erről a napról'),
      DateTime.now().weekday == DateTime.sunday ? findsNothing : findsOneWidget,
    );
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
    // Not this Sunday: the "Most vasárnap" row would show the mass a second
    // time.
    final day = DateTime.sunday - DateTime.now().weekday == 3 ? 2 : 3;
    final masses = _emptyDays();
    masses[day].add(
      CachedMass(
        id: null,
        apiMassId: null,
        churchId: 38,
        time: _todayAt(7, 30).add(Duration(days: day)),
        info: null,
        source: MassSource.nearbyMasses,
      ),
    );
    final data = _page(masses, scheduleIsFresh: true);

    await pumpPage(tester, _FakeLoader(cached: data, refreshed: data));

    // One card, for the only day that has anything.
    expect(find.text('7:30'), findsOneWidget);
    expect(find.byType(Card), findsWidgets);
  });

  testWidgets('a day with many masses grows wider, not taller: its times '
      'stay on one line, its card as tall as the others', (tester) async {
    // Not this Sunday: the "Most vasárnap" row would show the masses again.
    final sunday = DateTime.sunday - DateTime.now().weekday;
    final [few, many] =
        [
          for (var d = 1; d < 7; d++) d,
        ].where((d) => d != sunday).take(2).toList();
    CachedMass at(int day, int hour) => CachedMass(
      id: null,
      apiMassId: null,
      churchId: 38,
      time: _todayAt(hour, 20).add(Duration(days: day)),
      info: null,
      source: MassSource.nearbyMasses,
    );
    final masses = _emptyDays();
    masses[few].addAll([at(few, 7), at(few, 18)]);
    masses[many].addAll([
      for (final h in [6, 8, 10, 12, 19]) at(many, h),
    ]);
    final data = _page(masses, scheduleIsFresh: true);

    await pumpPage(tester, _FakeLoader(cached: data, refreshed: data));

    Rect cardOf(String time) => tester.getRect(
      find.ancestor(of: find.text(time), matching: find.byType(Card)).first,
    );
    final fewCard = cardOf('7:20');
    final manyCard = cardOf('6:20');
    expect(manyCard.height, fewCard.height);
    expect(manyCard.top, fewCard.top);
    expect(manyCard.width, greaterThan(fewCard.width));
    final tops = {
      for (final time in ['6:20', '8:20', '10:20', '12:20', '19:20'])
        tester.getTopLeft(find.text(time)).dy,
    };
    expect(tops, hasLength(1));
  });

  testWidgets('the day after the clocks go back is named by its own date', (
    tester,
  ) async {
    // 2026-10-25, the Sunday the clocks go back, has 25 hours.
    CachedMass at(DateTime time) => CachedMass(
      id: null,
      apiMassId: null,
      churchId: 38,
      time: time,
      info: null,
      source: MassSource.nearbyMasses,
    );
    final masses = _emptyDays();
    masses[17].add(at(DateTime(2026, 10, 25, 10, 0)));
    masses[18].add(at(DateTime(2026, 10, 26, 7, 30)));
    final data = _page(masses, scheduleIsFresh: true);

    await pumpPage(
      tester,
      _FakeLoader(cached: data, refreshed: data),
      clock: () => DateTime(2026, 10, 8, 10, 0),
    );

    expect(find.text('Vasárnap'), findsOneWidget);
    expect(find.text('2026. 10. 25.'), findsOneWidget);
    expect(find.text('Hétfő'), findsOneWidget);
    expect(find.text('2026. 10. 26.'), findsOneWidget);
  });

  testWidgets('no confession tile without a live response', (tester) async {
    // The cache says yes, but a cached value is a stale switch reading.
    final cached = _page(
      _emptyDays(),
      church: _details(hasConfession: true),
      confessionLive: false,
    );
    await pumpPage(tester, _FakeLoader(cached: cached, refreshed: cached));

    expect(find.text('Most gyóntatnak'), findsNothing);
  });

  testWidgets('confession tile appears for a live response', (tester) async {
    final loader = _FakeLoader(
      cached: _page(_emptyDays()),
      refreshed: _page(
        _emptyDays(),
        church: _details(hasConfession: true),
        confessionLive: true,
      ),
    );

    await pumpPage(tester, loader);
    loader.answerApi();
    await tester.pump();
    await tester.pump();

    expect(find.text('Most gyóntatnak'), findsOneWidget);
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

  testWidgets('languages are drawn as flags, named for screen readers', (
    tester,
  ) async {
    final data = _page(
      _emptyDays(),
      church: _details(languages: ['hu', 'en', 'ua']),
    );
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

  testWidgets('the Vatican flag stands for Latin, not for a country', (
    tester,
  ) async {
    // `va` and `tl` are miserend's own vocabulary, not ISO 639; reading them
    // as language codes is what used to render "VA" and "TL" as text.
    final data = _page(
      _emptyDays(),
      church: _details(languages: ['hu', 'va', 'tl']),
    );
    await pumpPage(tester, _FakeLoader(cached: data, refreshed: data));

    expect(find.text('VA'), findsNothing);
    expect(find.text('TL'), findsNothing);
    expect(find.bySemanticsLabel('latin'), findsOneWidget);
    expect(find.bySemanticsLabel('tagalog'), findsOneWidget);
  });

  testWidgets('a code with no flag falls back to text rather than vanishing', (
    tester,
  ) async {
    final data = _page(_emptyDays(), church: _details(languages: ['hu', 'zz']));
    await pumpPage(tester, _FakeLoader(cached: data, refreshed: data));

    expect(find.text('ZZ'), findsOneWidget);
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('an all-day adoration window is named, not printed as a range', (
    tester,
  ) async {
    final start = _todayAt(0, 0);
    final data = _page(
      _emptyDays(),
      church: _details(
        adorations: [
          Adoration(
            start: start,
            end: _todayAt(23, 59),
            kind: 'csendes',
            info: null,
          ),
        ],
      ),
    );

    await pumpPage(tester, _FakeLoader(cached: data, refreshed: data));

    expect(find.text('Szentségimádás'), findsOneWidget);
    expect(find.text('Egész nap · csendes'), findsOneWidget);
    expect(find.text('0:00–23:59 · csendes'), findsNothing);
  });

  testWidgets('an adoration window is an en dash range without spaces (FM1, '
      'FM5)', (tester) async {
    final data = _page(
      _emptyDays(),
      church: _details(
        adorations: [
          Adoration(
            start: _todayAt(9, 0),
            end: _todayAt(18, 0),
            kind: null,
            info: null,
          ),
        ],
      ),
    );

    await pumpPage(tester, _FakeLoader(cached: data, refreshed: data));

    expect(find.text('9:00–18:00'), findsOneWidget);
  });

  testWidgets('accessibility states a "no" plainly', (tester) async {
    final data = _page(
      _emptyDays(),
      church: _details(accessibility: {'wheelchair': 'no'}),
    );
    await pumpPage(tester, _FakeLoader(cached: data, refreshed: data));

    expect(find.text('Kerekesszékkel nem megközelíthető'), findsOneWidget);
  });

  group('marking data that is not live', () {
    Future<void> refreshWith(
      WidgetTester tester,
      ChurchPageData refreshed,
    ) async {
      final loader = _FakeLoader(
        cached: _page(_scheduleWith(_todayAt(9, 0))),
        refreshed: refreshed,
      );
      await pumpPage(tester, loader);
      loader.answerApi();
      await tester.pump();
      await tester.pump();
    }

    Color? bannerColor(WidgetTester tester) =>
        tester
            .widget<Material>(
              find
                  .descendant(
                    of: find.byType(OfflineBanner),
                    matching: find.byType(Material),
                  )
                  .first,
            )
            .color;

    testWidgets('nothing is marked while the API call is outstanding', (
      tester,
    ) async {
      final loader = _FakeLoader(
        cached: _page(_scheduleWith(_todayAt(9, 0))),
        refreshed: _page(
          _scheduleWith(_todayAt(9, 0)),
          failure: ApiFailure.noConnection,
        ),
      );

      await pumpPage(tester, loader);

      expect(find.byType(OfflineBanner), findsNothing);
    });

    testWidgets('nothing is marked after a successful refresh', (tester) async {
      await refreshWith(
        tester,
        _page(_scheduleWith(_todayAt(9, 0)), scheduleIsFresh: true),
      );

      expect(find.byType(OfflineBanner), findsNothing);
    });

    testWidgets('the banner goes away by itself once the connection is back, '
        'without the user touching anything', (tester) async {
      final loader = _FakeLoader(
        cached: _page(_scheduleWith(_todayAt(9, 0))),
        refreshed: _page(
          _scheduleWith(_todayAt(9, 0)),
          failure: ApiFailure.noConnection,
        ),
      );
      await pumpPage(tester, loader);
      loader.answerApi();
      await tester.pump();
      await tester.pump();
      expect(find.byType(OfflineBanner), findsOneWidget);
      final asked = loader.refreshes;

      // The phone comes back online between one retry and the next.
      loader.refreshed = _page(_scheduleWith(_todayAt(18, 30)));
      await tester.pump(StaleDataRetry.retryEvery);
      await tester.pump();

      expect(loader.refreshes, asked + 1, reason: 'it asked again on its own');
      expect(find.byType(OfflineBanner), findsNothing);
      expect(find.text('18:30'), findsWidgets);
    });

    testWidgets('a retry that fails again leaves the banner where it is', (
      tester,
    ) async {
      final loader = _FakeLoader(
        cached: _page(_scheduleWith(_todayAt(9, 0))),
        refreshed: _page(
          _scheduleWith(_todayAt(9, 0)),
          failure: ApiFailure.noConnection,
        ),
      );
      await pumpPage(tester, loader);
      loader.answerApi();
      await tester.pump();
      await tester.pump();

      await tester.pump(StaleDataRetry.retryEvery);
      await tester.pump();

      expect(find.byType(OfflineBanner), findsOneWidget);
    });

    testWidgets('no connection puts the lists\' banner above the page, '
        'untinted', (tester) async {
      await refreshWith(
        tester,
        _page(_scheduleWith(_todayAt(9, 0)), failure: ApiFailure.noConnection),
      );

      expect(find.byType(OfflineBanner), findsOneWidget);
      expect(find.byType(OfflineInfoButton), findsOneWidget);
      expect(
        bannerColor(tester),
        isNot(
          miserendTheme(
            Brightness.light,
          ).extension<MiserendColors>()!.serverErrorContainer,
        ),
      );
      expect(
        tester.getTopLeft(find.byType(OfflineBanner)).dy,
        lessThan(tester.getTopLeft(find.text('Ma')).dy),
      );
    });

    testWidgets('a server error tints the banner, not the masses card', (
      tester,
    ) async {
      await refreshWith(
        tester,
        _page(_scheduleWith(_todayAt(9, 0)), failure: ApiFailure.serverError),
      );

      expect(
        bannerColor(tester),
        miserendTheme(
          Brightness.light,
        ).extension<MiserendColors>()!.serverErrorContainer,
      );
      expect(find.byType(OfflineInfoButton), findsOneWidget);
      final massCard = tester.widget<Card>(
        find.ancestor(of: find.text('Ma'), matching: find.byType(Card)).first,
      );
      expect(massCard.color, isNull);
    });

    testWidgets('the (i) tells how old the data is and what to do', (
      tester,
    ) async {
      await refreshWith(
        tester,
        _page(
          _scheduleWith(_todayAt(9, 0)),
          failure: ApiFailure.noConnection,
          dataAsOf: DateTime(2026, 8, 1, 10, 0),
        ),
      );

      await tester.tap(find.byType(OfflineInfoButton));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Az adatok a telefonon tárolt, 2026. 08. 01. óta nem frissült '
          'állapotot mutatják. '
          'Kapcsold be az adatkapcsolatot, vagy ellenőrizd, hogy a '
          'Miserend használhat-e mobilnetet a telefon beállításaiban — '
          'amint újra van kapcsolat, a képernyő magától frissül.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the (i) of a server error says miserend.hu is unavailable', (
      tester,
    ) async {
      await refreshWith(
        tester,
        _page(
          _scheduleWith(_todayAt(9, 0)),
          failure: ApiFailure.serverError,
          dataAsOf: DateTime(2026, 8, 1, 10, 0),
        ),
      );

      await tester.tap(find.byType(OfflineInfoButton));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'A miserend.hu jelenleg nem elérhető, az adatok a '
          '2026. 08. 01. óta nem frissült állapotot mutatják.',
        ),
        findsOneWidget,
      );
    });
  });

  group('problem report', () {
    const blocked =
        'Hibát jelenteni csak kapcsolat mellett lehet. Amint a miserend.hu '
        'újra elérhető, a gomb magától visszajön.';

    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<_FakeLoader> answered(
      WidgetTester tester,
      ChurchPageData refreshed,
    ) async {
      final loader = _FakeLoader(
        cached: _page(_scheduleWith(_todayAt(9, 0))),
        refreshed: refreshed,
      );
      await pumpPage(tester, loader);
      loader.answerApi();
      await tester.pump();
      await tester.pump();
      return loader;
    }

    Future<void> tapReport(WidgetTester tester) async {
      await tester.tap(find.text('Hibajelentés'));
      await tester.pumpAndSettle();
    }

    TextButton reportButton(WidgetTester tester) => tester.widget<TextButton>(
      find.ancestor(
        of: find.text('Hibajelentés'),
        matching: find.byType(TextButton),
      ),
    );

    testWidgets('while blocked, the button greys out as a disabled one, '
        'not in a colour of its own', (tester) async {
      await answered(
        tester,
        _page(_scheduleWith(_todayAt(9, 0)), failure: ApiFailure.noConnection),
      );

      expect(reportButton(tester).enabled, isFalse);
      expect(reportButton(tester).style, isNull);
    });

    testWidgets('with live data, the button is enabled', (tester) async {
      await answered(tester, _page(_scheduleWith(_todayAt(9, 0))));

      expect(reportButton(tester).enabled, isTrue);
    });

    for (final failure in ApiFailure.values) {
      testWidgets('with ${failure.name} marked, the button explains itself '
          'instead of opening the page', (tester) async {
        await answered(
          tester,
          _page(_scheduleWith(_todayAt(9, 0)), failure: failure),
        );

        await tapReport(tester);

        expect(find.text(blocked), findsOneWidget);
        expect(find.byType(ReportProblemPage), findsNothing);
      });
    }

    testWidgets('with nothing marked, the button opens the page for the '
        'church and the day of its data', (tester) async {
      await answered(
        tester,
        _page(
          _scheduleWith(_todayAt(9, 0)),
          church: _details(),
          scheduleIsFresh: true,
          dataAsOf: DateTime(2026, 9, 3, 17, 45),
        ),
      );

      await tapReport(tester);

      final page = tester.widget<ReportProblemPage>(
        find.byType(ReportProblemPage),
      );
      expect(page.churchId, 38);
      expect(page.churchName, 'Belvárosi Nagyboldogasszony-templom');
      expect(page.dataAsOf, DateTime(2026, 9, 3, 17, 45));
      expect(find.text(blocked), findsNothing);
    });

    testWidgets(
      'while the API call is outstanding, the button opens the page',
      (tester) async {
        final loader = _FakeLoader(
          cached: _page(_scheduleWith(_todayAt(9, 0))),
          refreshed: _page(
            _scheduleWith(_todayAt(9, 0)),
            failure: ApiFailure.noConnection,
          ),
        );
        await pumpPage(tester, loader);

        await tapReport(tester);

        expect(find.byType(ReportProblemPage), findsOneWidget);

        // Let the outstanding refresh finish before the test ends.
        loader.answerApi();
        await tester.pumpAndSettle();
      },
    );

    testWidgets('a successful retry brings the button back by itself', (
      tester,
    ) async {
      final loader = await answered(
        tester,
        _page(_scheduleWith(_todayAt(9, 0)), failure: ApiFailure.noConnection),
      );

      loader.refreshed = _page(_scheduleWith(_todayAt(9, 0)));
      await tester.pump(StaleDataRetry.retryEvery);
      await tester.pump();
      await tapReport(tester);

      expect(find.byType(ReportProblemPage), findsOneWidget);
      expect(find.text(blocked), findsNothing);
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

    expect(
      find.text('Ez a templom már nem szerepel a miserend.hu-n.'),
      findsOneWidget,
    );
    expect(find.text('9:00'), findsNothing);
    expect(find.text('Nincs adat a mai miserendről'), findsNothing);
    expect(find.text('Most vasárnap'), findsNothing);
    expect(find.byType(ChurchDetailsPage), findsOneWidget);
    // The name the page was opened with stays readable.
    expect(find.text('Belvárosi Nagyboldogasszony-templom'), findsOneWidget);
  });

  group('location card', () {
    testWidgets('marks the church with the miserend.hu pin', (tester) async {
      final empty = _page(_emptyDays());

      await pumpPage(tester, _FakeLoader(cached: empty, refreshed: empty));

      final map = tester.widget<MiserendMap>(find.byType(MiserendMap));
      expect(map.markers.single.point.latitude, _church.lat);
      final pin = find.descendant(
        of: find.byType(MiserendMap),
        matching: find.byKey(MiserendMap.markerKey(_church.id)),
      );
      expect(pin, findsWidgets);
    });

    testWidgets('carries no blue dot: at this zoom the user is off the card', (
      tester,
    ) async {
      final empty = _page(_emptyDays());

      await pumpPage(tester, _FakeLoader(cached: empty, refreshed: empty));

      final map = tester.widget<MiserendMap>(find.byType(MiserendMap));
      expect(map.userPosition, isNull);
      expect(find.byKey(MiserendMap.userPositionKey), findsNothing);
    });
  });
}
