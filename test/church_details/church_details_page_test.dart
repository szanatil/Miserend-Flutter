import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/church_details/church_details_page.dart';
import 'package:miserend/church_details/church_schedule_loader.dart';
import 'package:miserend/database/cache/cached_mass.dart';
import 'package:miserend/database/church.dart';
import 'package:miserend/database/favorites_service.dart';
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

List<List<CachedMass>> _scheduleWith(DateTime time) {
  final days = List.generate(
      ChurchScheduleLoader.scheduleDays, (_) => <CachedMass>[]);
  days[0].add(CachedMass(
    id: null,
    apiMassId: null,
    churchId: 38,
    time: time,
    info: 'Szentmise',
  ));
  return days;
}

/// Stands in for the real loader so that the page can be pumped without a
/// database or a network call. [answerApi] releases the refresh, so a test can
/// look at the page while the API call is still outstanding.
class _FakeLoader extends ChurchScheduleLoader {
  _FakeLoader({required this.cached, required this.refreshed});

  final List<List<CachedMass>> cached;
  final List<List<CachedMass>> refreshed;
  final Completer<void> _apiAnswered = Completer<void>();

  void answerApi() => _apiAnswered.complete();

  @override
  Future<List<List<CachedMass>>> loadCached(int churchId, DateTime today) async =>
      cached;

  @override
  Future<List<List<CachedMass>>> refresh(Church church, DateTime today) async {
    await _apiAnswered.future;
    return refreshed;
  }
}

void main() {
  // FavoritesService opens a database from its constructor, so the factory has
  // to exist even though this test never reads a favorite.
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  Future<void> pumpPage(WidgetTester tester, ChurchScheduleLoader loader) async {
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => FavoritesService(),
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
      cached: _scheduleWith(_todayAt(9, 0)),
      refreshed: _scheduleWith(_todayAt(18, 30)),
    );

    await pumpPage(tester, loader);

    expect(find.text('09:00'), findsWidgets);
    expect(find.text('18:30'), findsNothing);
  });

  testWidgets('shows the refreshed schedule once the API has answered',
      (tester) async {
    final loader = _FakeLoader(
      cached: _scheduleWith(_todayAt(9, 0)),
      refreshed: _scheduleWith(_todayAt(18, 30)),
    );

    await pumpPage(tester, loader);
    loader.answerApi();
    await tester.pump();
    await tester.pump();

    expect(find.text('18:30'), findsWidgets);
    expect(find.text('09:00'), findsNothing);
  });

  testWidgets('shows the church name', (tester) async {
    final empty = List.generate(
        ChurchScheduleLoader.scheduleDays, (_) => <CachedMass>[]);
    await pumpPage(
        tester, _FakeLoader(cached: empty, refreshed: empty));

    expect(find.text('Belvárosi Nagyboldogasszony-templom'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
