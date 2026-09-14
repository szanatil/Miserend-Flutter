import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/api/nearby_masses_item.dart';
import 'package:miserend/church_details/church_details_page.dart';
import 'package:miserend/church_details/church_page_data.dart';
import 'package:miserend/church_details/church_schedule_loader.dart';
import 'package:miserend/database/cache/cached_mass.dart';
import 'package:miserend/database/church.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/home/masses/mass_list_item.dart';
import 'package:miserend/home/masses/near_masses_page.dart';
import 'package:miserend/home/masses/nearest_masses_loader.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

NearbyMassesItem _mass({
  int church = 1,
  String name = 'Szent István-bazilika',
  String city = 'Budapest V. kerület',
  double km = 1.08,
  required DateTime start,
  String title = 'Szentmise',
}) {
  return NearbyMassesItem(
    churchId: church,
    churchName: name,
    city: city,
    lat: 47.5007789,
    lon: 19.0539695,
    distanceKm: km,
    start: start,
    title: title,
  );
}

DateTime _at(int hour, int minute) => DateTime(2026, 9, 14, hour, minute);

/// The blurred church placeholder, looking through the resize wrapper that
/// decoding at thumbnail size puts around it.
Finder _placeholderImage() => find.byWidgetPredicate((widget) {
      if (widget is! Image) return false;
      var provider = widget.image;
      if (provider is ResizeImage) provider = provider.imageProvider;
      return provider is AssetImage &&
          provider.assetName == 'assets/images/church_blurred.png';
    });

/// Stands in for the real loader so that the page can be pumped without a
/// position, a network call or a database. Each fetch takes the next answer:
/// a list of items, an exception to throw, or a completer to wait on.
class _FakeLoader extends NearestMassesLoader {
  _FakeLoader(List<Object> answers) : _answers = Queue.of(answers);

  final Queue<Object> _answers;
  int fetchCount = 0;

  @override
  Future<List<NearbyMassesItem>> fetch(DateTime now) async {
    fetchCount++;
    final answer = _answers.length > 1 ? _answers.removeFirst() : _answers.first;
    if (answer is Exception) throw answer;
    if (answer is Completer<List<NearbyMassesItem>>) return answer.future;
    return answer as List<NearbyMassesItem>;
  }

  Completer<String?>? thumbnail;
  final List<int> thumbnailsAskedFor = [];

  @override
  Future<String?> thumbnailUrl(int churchId) {
    thumbnailsAskedFor.add(churchId);
    return thumbnail?.future ?? Future.value(null);
  }
}

/// Lets the details page open without a database or a network call.
class _EmptyDetailsLoader extends ChurchScheduleLoader {
  ChurchPageData get _empty => ChurchPageData(
        church: null,
        massesByDay: List.generate(
            ChurchScheduleLoader.scheduleDays, (_) => <CachedMass>[]),
        scheduleIsFresh: false,
        confessionLive: false,
      );

  @override
  Future<ChurchPageData> loadCached(int churchId, DateTime today) async =>
      _empty;

  @override
  Future<ChurchPageData> refresh(Church church, DateTime today) async => _empty;
}

void main() {
  late DateTime now;

  setUp(() => now = _at(12, 0));

  // The details page reads favorites from its initState, so the factory has to
  // exist. Built once, in the real async zone: see church_details_page_test.
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late FavoritesService favorites;

  setUpAll(() async {
    favorites = FavoritesService();
    for (var i = 0; i < 400 && !favorites.loaded; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  });

  Future<void> pumpPage(WidgetTester tester, NearestMassesLoader loader,
      {bool isActive = true}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NearMassesPage(
            loader: loader, clock: () => now, isActive: isActive),
      ),
    ));
    await tester.pump();
  }

  /// Like [pumpPage], but able to open the real details page on top.
  Future<void> pumpWithDetails(
      WidgetTester tester, NearestMassesLoader loader) async {
    await tester.pumpWidget(ChangeNotifierProvider<FavoritesService>.value(
      value: favorites,
      child: MaterialApp(
        home: Scaffold(
          body: NearMassesPage(
            loader: loader,
            clock: () => now,
            detailsLoader: _EmptyDetailsLoader(),
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  Future<void> pullToRefresh(WidgetTester tester) async {
    await tester.fling(
        find.byType(Scrollable).first, const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> goToBackgroundAndBack(WidgetTester tester,
      {Future<void> Function()? whileAway}) async {
    final binding = tester.binding;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await whileAway?.call();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
  }

  group('states', () {
    testWidgets('shows the loading caption while the first fetch is outstanding',
        (tester) async {
      await pumpPage(tester, _FakeLoader([Completer<List<NearbyMassesItem>>()]));

      expect(find.text('Legközelebbi misék betöltése…'), findsOneWidget);
    });

    testWidgets('says so when the position cannot be determined',
        (tester) async {
      await pumpPage(tester, _FakeLoader([const LocationUnavailable()]));

      expect(
          find.text('Nem sikerült meghatározni a helyzetedet, ezért a '
              'legközelebbi misék nem jeleníthetőek meg.'),
          findsOneWidget);
    });

    testWidgets('says so when the masses cannot be loaded', (tester) async {
      await pumpPage(tester, _FakeLoader([const MassesUnavailable()]));

      expect(
          find.text('Nem sikerült betölteni a miséket. '
              'Ellenőrizd az internetkapcsolatot.'),
          findsOneWidget);
    });

    testWidgets('says so when no mass is reachable nearby', (tester) async {
      await pumpPage(
        tester,
        _FakeLoader([
          [_mass(start: _at(15, 0), title: 'Gyóntatás')],
        ]),
      );

      expect(find.text('A közelben ma már nincs elérhető mise.'), findsOneWidget);
    });

    testWidgets('lists the church name and the 24-hour start', (tester) async {
      await pumpPage(
        tester,
        _FakeLoader([
          [_mass(start: _at(18, 30))],
        ]),
      );

      expect(find.text('Szent István-bazilika'), findsOneWidget);
      expect(find.text('18:30'), findsOneWidget);
    });
  });

  group('row', () {
    testWidgets('shows the city and the distance with a decimal comma',
        (tester) async {
      await pumpPage(
        tester,
        _FakeLoader([
          [_mass(start: _at(18, 30), km: 1.23)],
        ]),
      );

      expect(find.text('Budapest V. kerület'), findsOneWidget);
      expect(find.text('1,2 km'), findsOneWidget);
    });

    testWidgets('marks a mass as ongoing only once it has started',
        (tester) async {
      now = _at(14, 5);
      await pumpPage(
        tester,
        _FakeLoader([
          [
            _mass(church: 1, name: 'Elkezdődött', start: _at(14, 0)),
            _mass(church: 2, name: 'Még nem', start: _at(14, 30)),
          ],
        ]),
      );

      expect(find.text('Épp most tart'), findsOneWidget);
      final ongoingRow = find.ancestor(
          of: find.text('Elkezdődött'), matching: find.byType(MassListItem));
      expect(
          find.descendant(of: ongoingRow, matching: find.text('Épp most tart')),
          findsOneWidget);
    });

    testWidgets('shows the title only when it is not plain Szentmise',
        (tester) async {
      await pumpPage(
        tester,
        _FakeLoader([
          [
            _mass(church: 1, start: _at(17, 0), title: 'Szentmise'),
            _mass(church: 2, start: _at(18, 0), title: 'Szent Liturgia'),
          ],
        ]),
      );

      expect(find.text('Szent Liturgia'), findsOneWidget);
      expect(find.text('Szentmise'), findsNothing);
    });

    testWidgets('asks for the thumbnail by church id and shows the list '
        'before it arrives', (tester) async {
      final loader = _FakeLoader([
        [_mass(church: 37, start: _at(18, 0))],
      ])
        ..thumbnail = Completer<String?>();

      await pumpPage(tester, loader);

      expect(find.text('Szent István-bazilika'), findsOneWidget);
      expect(loader.thumbnailsAskedFor, [37]);
      expect(_placeholderImage(),
          findsOneWidget);
    });

    testWidgets('keeps the placeholder when the cache has no photo',
        (tester) async {
      final loader = _FakeLoader([
        [_mass(church: 37, start: _at(18, 0))],
      ])
        ..thumbnail = (Completer<String?>()..complete(null));

      await pumpPage(tester, loader);
      await tester.pump();

      expect(_placeholderImage(),
          findsOneWidget);
    });

    testWidgets('tapping a row opens the details page of that church',
        (tester) async {
      await pumpWithDetails(
        tester,
        _FakeLoader([
          [
            _mass(church: 1, name: 'Első', start: _at(17, 0)),
            _mass(church: 37, name: 'Második', start: _at(18, 0)),
          ],
        ]),
      );

      await tester.tap(find.text('Második'));
      await tester.pumpAndSettle();

      final details =
          tester.widget<ChurchDetailsPage>(find.byType(ChurchDetailsPage));
      expect(details.church.id, 37);
      expect(details.church.name, 'Második');
      expect(details.church.city, 'Budapest V. kerület');
      expect(details.church.lat, 47.5007789);
      expect(details.church.lon, 19.0539695);
    });
  });

  group('refresh', () {
    testWidgets('fetches once when the page first appears', (tester) async {
      final loader = _FakeLoader([
        [_mass(start: _at(18, 0))],
      ]);

      await pumpPage(tester, loader);

      expect(loader.fetchCount, 1);
    });

    testWidgets('pulling down fetches again from the list', (tester) async {
      final loader = _FakeLoader([
        [_mass(name: 'Régi', start: _at(18, 0))],
        [_mass(name: 'Friss', start: _at(18, 0))],
      ]);
      await pumpPage(tester, loader);

      await pullToRefresh(tester);

      expect(loader.fetchCount, 2);
      expect(find.text('Friss'), findsOneWidget);
    });

    testWidgets('pulling down fetches again from the error message',
        (tester) async {
      final loader = _FakeLoader([
        const MassesUnavailable(),
        [_mass(name: 'Friss', start: _at(18, 0))],
      ]);
      await pumpPage(tester, loader);

      await pullToRefresh(tester);

      expect(loader.fetchCount, 2);
      expect(find.text('Friss'), findsOneWidget);
    });

    testWidgets('pulling down fetches again from the empty message',
        (tester) async {
      final loader = _FakeLoader([
        <NearbyMassesItem>[],
        [_mass(name: 'Friss', start: _at(18, 0))],
      ]);
      await pumpPage(tester, loader);

      await pullToRefresh(tester);

      expect(loader.fetchCount, 2);
      expect(find.text('Friss'), findsOneWidget);
    });

    testWidgets('coming back to the app fetches again while the tab is shown',
        (tester) async {
      final loader = _FakeLoader([
        [_mass(start: _at(18, 0))],
      ]);
      await pumpPage(tester, loader);

      await goToBackgroundAndBack(tester);

      expect(loader.fetchCount, 2);
    });

    testWidgets('coming back to the app does not fetch while another tab is '
        'shown', (tester) async {
      final loader = _FakeLoader([
        [_mass(start: _at(18, 0))],
      ]);
      await pumpPage(tester, loader);
      await pumpPage(tester, loader, isActive: false);

      await goToBackgroundAndBack(tester);

      expect(loader.fetchCount, 1);
    });

    testWidgets('switching back to the tab fetches again', (tester) async {
      final loader = _FakeLoader([
        [_mass(start: _at(18, 0))],
      ]);
      await pumpPage(tester, loader);
      await pumpPage(tester, loader, isActive: false);

      await pumpPage(tester, loader, isActive: true);

      expect(loader.fetchCount, 2);
    });
  });

  group('every minute', () {
    testWidgets('an expired mass gives way to the same church\'s next one, '
        'without a network call', (tester) async {
      now = _at(14, 5);
      final loader = _FakeLoader([
        [
          _mass(church: 1, start: _at(14, 0)),
          _mass(church: 1, start: _at(18, 30)),
        ],
      ]);
      await pumpPage(tester, loader);
      expect(find.text('14:00'), findsOneWidget);

      now = _at(14, 11);
      await tester.pump(const Duration(minutes: 1));

      expect(find.text('14:00'), findsNothing);
      expect(find.text('18:30'), findsOneWidget);
      expect(loader.fetchCount, 1);
    });

    testWidgets('a church with no mass left gives way to the next nearest '
        'church, without a network call', (tester) async {
      now = _at(14, 5);
      final loader = _FakeLoader([
        [
          _mass(church: 1, name: 'Templom 1', km: 1, start: _at(14, 0)),
          for (var church = 2; church <= 11; church++)
            _mass(
                church: church,
                name: 'Templom $church',
                km: church.toDouble(),
                start: _at(18, 0)),
        ],
      ]);
      // Tall enough to build all ten rows.
      tester.view.physicalSize = const Size(1000, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpPage(tester, loader);
      expect(find.text('Templom 11'), findsNothing);

      now = _at(14, 11);
      await tester.pump(const Duration(minutes: 1));

      expect(find.text('Templom 1'), findsNothing);
      expect(find.text('Templom 11'), findsOneWidget);
      expect(loader.fetchCount, 1);
    });

    testWidgets('fetches again once the day has changed', (tester) async {
      now = DateTime(2026, 9, 14, 23, 59);
      final loader = _FakeLoader([
        [_mass(start: DateTime(2026, 9, 15, 0, 0))],
      ]);
      await pumpPage(tester, loader);

      now = DateTime(2026, 9, 15, 0, 0);
      await tester.pump(const Duration(minutes: 1));

      expect(loader.fetchCount, 2);
    });

    testWidgets('does not run while another tab is shown', (tester) async {
      now = DateTime(2026, 9, 14, 23, 58);
      final loader = _FakeLoader([
        [_mass(start: DateTime(2026, 9, 15, 0, 0))],
      ]);
      await pumpPage(tester, loader);
      await pumpPage(tester, loader, isActive: false);

      now = DateTime(2026, 9, 15, 0, 1);
      await tester.pump(const Duration(minutes: 2));

      expect(loader.fetchCount, 1);
    });

    testWidgets('does not run while a details page covers the list, and '
        'catches up once it is closed', (tester) async {
      now = DateTime(2026, 9, 14, 23, 58);
      final loader = _FakeLoader([
        [_mass(name: 'Éjféli', start: DateTime(2026, 9, 15, 0, 0))],
      ]);
      await pumpWithDetails(tester, loader);
      await tester.tap(find.text('Éjféli'));
      await tester.pumpAndSettle();

      now = DateTime(2026, 9, 15, 0, 1);
      await tester.pump(const Duration(minutes: 2));
      expect(loader.fetchCount, 1);

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(loader.fetchCount, 2);
    });

    testWidgets('does not run while the app is in the background',
        (tester) async {
      now = DateTime(2026, 9, 14, 23, 58);
      final loader = _FakeLoader([
        [_mass(start: DateTime(2026, 9, 15, 0, 0))],
      ]);
      await pumpPage(tester, loader);

      var fetchesWhileAway = -1;
      await goToBackgroundAndBack(tester, whileAway: () async {
        now = DateTime(2026, 9, 15, 0, 1);
        await tester.pump(const Duration(minutes: 2));
        fetchesWhileAway = loader.fetchCount;
      });

      expect(fetchesWhileAway, 1);
    });
  });

  group('formatDistance', () {
    test('rounds to one decimal and uses a decimal comma', () {
      expect(formatDistance(1.23), '1,2 km');
      expect(formatDistance(0.64), '0,6 km');
      expect(formatDistance(12), '12,0 km');
    });
  });
}
