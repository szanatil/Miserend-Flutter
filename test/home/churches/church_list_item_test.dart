import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/database/church.dart';
import 'package:miserend/database/church_with_masses.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/database/mass.dart';
import 'package:miserend/home/churches/church_list_item.dart';
import 'package:miserend/widgets/time_chip.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Church _church() => Church(
      id: 38,
      name: 'Belvárosi templom',
      commonName: 'Főplébániatemplom',
      isGreek: false,
      lat: 47.49,
      lon: 19.05,
      address: null,
      city: 'Budapest',
      country: null,
      county: null,
      street: null,
      gettingThere: null,
      imageUrl: null,
    );

/// Held every day of the year, so it shows up whatever day the test runs on.
Mass _dailyMass() => Mass(
      id: 1,
      churchId: 38,
      day: 0,
      time: const TimeOfDay(hour: 17, minute: 0),
      season: null,
      language: null,
      tags: null,
      period: null,
      weight: null,
      startDate: 101,
      endDate: 1231,
      comment: null,
    );

void main() {
  // The card reads favorites, which live in a local database.
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late FavoritesService favorites;

  setUpAll(() async {
    favorites = FavoritesService();
    for (var i = 0; i < 400 && !favorites.loaded; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  });

  Future<void> pumpCard(WidgetTester tester, ChurchWithMasses church) async {
    await tester.pumpWidget(ChangeNotifierProvider<FavoritesService>.value(
      value: favorites,
      child: MaterialApp(
        home: Scaffold(body: ChurchListItem(churchWithMasses: church)),
      ),
    ));
  }

  testWidgets('shows the mass times of an export that is still valid',
      (tester) async {
    await pumpCard(tester, ChurchWithMasses(_church(), [_dailyMass()]));

    expect(find.byType(TimeChip), findsOneWidget);
    expect(find.textContaining('elavult'), findsNothing);
  });

  testWidgets('says the schedule is outdated instead of showing masses',
      (tester) async {
    await pumpCard(
        tester, ChurchWithMasses(_church(), [], massesExpired: true));

    expect(find.byType(TimeChip), findsNothing);
    expect(find.textContaining('elavult'), findsOneWidget);
    expect(find.text('Belvárosi templom'), findsOneWidget,
        reason: 'the church itself stays visible');
  });
}
