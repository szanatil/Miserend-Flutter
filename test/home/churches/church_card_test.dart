import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miserend/api/api_result.dart';
import 'package:miserend/database/cache/cached_mass.dart';
import 'package:miserend/database/cache/church_list_entry.dart';
import 'package:miserend/database/favorite.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/home/churches/church_card.dart';
import 'package:miserend/theme/miserend_theme.dart';
import 'package:miserend/theme/tokens.dart';
import 'package:miserend/widgets/distance_chip.dart';
import 'package:miserend/widgets/time_chip.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../theme/theme_harness.dart';

/// Kecskemét's main square; the church stands about 300 m away.
const _position = LatLng(46.9062, 19.6913);

CachedMass _mass(int hour, int minute) => CachedMass(
  id: null,
  apiMassId: null,
  churchId: 1,
  time: DateTime(2026, 9, 15, hour, minute),
  info: null,
  source: MassSource.bootstrap,
);

ChurchListEntry _entry({
  String name = 'Nagytemplom',
  String? commonName = 'Szent Miklós',
  double? lat = 46.9089,
  double? lon = 19.6913,
  List<CachedMass> masses = const [],
}) => ChurchListEntry(
  id: 1,
  name: name,
  commonName: commonName,
  city: 'Kecskemét',
  lat: lat,
  lon: lon,
  photo: null,
  masses: masses,
);

void main() {
  // The heart reads favorites, which live in a local database. Built once, in
  // the real async zone: see church_details_page_test.
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late FavoritesService favorites;

  setUpAll(() async {
    favorites = FavoritesService();
    for (var i = 0; i < 400 && !favorites.loaded; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  });

  Future<void> pumpCard(
    WidgetTester tester,
    ChurchListEntry entry, {
    LatLng? position,
    double width = 400,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<FavoritesService>.value(
        value: favorites,
        child: MaterialApp(
          theme: miserendTheme(Brightness.light),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: ChurchCard(entry: entry, position: position),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('distance', () {
    testWidgets('shows the straight-line distance from the position', (
      tester,
    ) async {
      await pumpCard(tester, _entry(), position: _position);

      expect(find.byType(DistanceChip), findsOneWidget);
      expect(find.text('300 m'), findsOneWidget);
    });

    testWidgets('sits in the bottom right corner of the photo', (tester) async {
      await pumpCard(tester, _entry(), position: _position);

      final photo = tester.getRect(find.byType(Image));
      final chip = tester.getRect(find.byType(DistanceChip));
      expect(photo.right - chip.right, 8);
      expect(photo.bottom - chip.bottom, 8);
    });

    testWidgets('is left out without a position, and moves nothing', (
      tester,
    ) async {
      await pumpCard(tester, _entry(), position: _position);
      final heart = tester.getTopLeft(find.byType(IconButton));

      await pumpCard(tester, _entry());

      expect(find.byType(DistanceChip), findsNothing);
      expect(tester.getTopLeft(find.byType(IconButton)), heart);
      expect(find.text('Nagytemplom'), findsOneWidget);
      expect(find.text('Szent Miklós'), findsOneWidget);
    });

    for (final (lat, lon) in [(null, 19.6913), (46.9089, null), (0.0, 0.0)]) {
      testWidgets('is left out for a church at ($lat, $lon)', (tester) async {
        await pumpCard(tester, _entry(lat: lat, lon: lon), position: _position);

        expect(find.byType(DistanceChip), findsNothing);
      });
    }
  });

  group('layout', () {
    const longName =
        'Kecskeméti Szent Miklós Ferences Templom és Kolostor Plébánia '
        'Templom Alsóvárosi Rész Nagyon Hosszú Névvel';
    const longCommonName =
        'Alsóvárosi templom, Ferences templom, Barátok temploma';

    testWidgets('a long name and a long common name do not overflow', (
      tester,
    ) async {
      await pumpCard(
        tester,
        _entry(name: longName, commonName: longCommonName),
        position: _position,
        width: 360,
      );

      expect(tester.takeException(), isNull);
      expect(tester.widget<Text>(find.text(longName)).maxLines, 2);
      expect(tester.widget<Text>(find.text(longCommonName)).maxLines, 1);
    });

    testWidgets('the mass chips and the heart stand at the same height '
        'whatever the names', (tester) async {
      final masses = [_mass(8, 0)];
      await pumpCard(
        tester,
        _entry(name: 'Rövid', commonName: null, masses: masses),
      );
      final chip = tester.getTopLeft(find.byType(TimeChip));
      final heart = tester.getTopLeft(find.byType(IconButton));

      await pumpCard(
        tester,
        _entry(name: longName, commonName: longCommonName, masses: masses),
      );

      expect(tester.getTopLeft(find.byType(TimeChip)).dy, chip.dy);
      expect(tester.getTopLeft(find.byType(IconButton)).dy, heart.dy);
    });

    testWidgets('masses that do not fit on one line give way to a „…" chip', (
      tester,
    ) async {
      await pumpCard(
        tester,
        _entry(masses: [for (var hour = 6; hour < 20; hour++) _mass(hour, 30)]),
        width: 320,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('…'), findsOneWidget);
      expect(find.text('19:30'), findsNothing);
      final tops = {
        for (final element in find.byType(TimeChip).evaluate())
          tester.getTopLeft(find.byWidget(element.widget)).dy,
      };
      expect(tops, hasLength(1));
      final photo = tester.getRect(find.byType(Image));
      for (final element in find.byType(TimeChip).evaluate()) {
        expect(
          tester.getRect(find.byWidget(element.widget)).right,
          lessThanOrEqualTo(photo.left),
        );
      }
    });

    testWidgets('every mass shows, with no „…" chip, while all of them fit', (
      tester,
    ) async {
      await pumpCard(tester, _entry(masses: [_mass(8, 0), _mass(18, 0)]));

      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('18:00'), findsOneWidget);
      expect(find.text('…'), findsNothing);
    });
  });

  group('design', () {
    Future<void> pumpDesigned(
      WidgetTester tester, {
      ChurchListEntry? entry,
      Brightness brightness = Brightness.light,
      TargetPlatform platform = TargetPlatform.android,
      double width = 400,
      double textScale = 1,
      ApiFailure? failure,
      DateTime? now,
    }) async {
      await pumpThemed(
        tester,
        ChangeNotifierProvider<FavoritesService>.value(
          value: favorites,
          child: ChurchCard(
            entry: entry ?? _entry(masses: [_mass(8, 0), _mass(18, 0)]),
            position: _position,
            failure: failure,
            clock: () => now ?? DateTime(2026, 9, 15, 12, 0),
          ),
        ),
        brightness: brightness,
        platform: platform,
        width: width,
        textScale: textScale,
      );
    }

    Material cardSurface(WidgetTester tester) => tester.widget<Material>(
      find
          .descendant(of: find.byType(Card), matching: find.byType(Material))
          .first,
    );

    for (final brightness in Brightness.values) {
      group('in $brightness', () {
        final scheme = schemeOf(brightness);
        final colors = miserendColorsOf(brightness);

        testWidgets('the card is the theme card, raised 1 (KO1, MÉ1)', (
          tester,
        ) async {
          await pumpDesigned(tester, brightness: brightness);

          final surface = cardSurface(tester);
          expect(surface.color, scheme.surfaceContainerLow);
          expect(surface.elevation, 1);
          expect(
            surface.shape,
            const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(Radii.m)),
            ),
          );
        });

        testWidgets('under a server error the card is serverErrorContainer '
            '(SZ4)', (tester) async {
          await pumpDesigned(
            tester,
            brightness: brightness,
            failure: ApiFailure.serverError,
          );

          expect(cardSurface(tester).color, colors.serverErrorContainer);
        });

        testWidgets('the common name is bodyMedium onSurfaceVariant, the '
            'line outlineVariant (TI2, SZ5)', (tester) async {
          await pumpDesigned(tester, brightness: brightness);

          final textTheme =
              Theme.of(tester.element(find.byType(ChurchCard))).textTheme;
          final common = drawnStyle(tester, find.text('Szent Miklós'));
          expect(common.fontSize, textTheme.bodyMedium!.fontSize);
          expect(common.color, scheme.onSurfaceVariant);
          expect(
            tester.widget<Divider>(find.byType(Divider)).color,
            scheme.outlineVariant,
          );
        });

        testWidgets('the heart is filled primary for a favorite, outlined '
            'onSurfaceVariant otherwise (IK1, IK2, IK4)', (tester) async {
          // Set in memory: the database answers in the real async zone only.
          final saved = favorites.favorites;
          addTearDown(() => favorites.favorites = saved);
          favorites.favorites = [];
          await pumpDesigned(tester, brightness: brightness);

          expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
          expect(
            tester.widget<IconButton>(find.byType(IconButton)).color,
            scheme.onSurfaceVariant,
          );

          favorites.favorites = [Favorite(churchId: 1)];
          await pumpDesigned(tester, brightness: brightness);

          expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
          expect(
            tester.widget<IconButton>(find.byType(IconButton)).color,
            scheme.primary,
          );
        });

        testWidgets('a mass going on now has its chip in the filled orange '
            '(KO3)', (tester) async {
          await pumpDesigned(
            tester,
            brightness: brightness,
            now: DateTime(2026, 9, 15, 18, 5),
          );

          final ongoing = tester.widget<TimeChip>(
            find.ancestor(
              of: find.text('18:00'),
              matching: find.byType(TimeChip),
            ),
          );
          final later = tester.widget<TimeChip>(
            find.ancestor(
              of: find.text('08:00'),
              matching: find.byType(TimeChip),
            ),
          );
          expect(ongoing.ongoing, isTrue);
          expect(later.ongoing, isFalse);
        });
      });
    }

    testWidgets('the name is titleMedium (TI2)', (tester) async {
      await pumpDesigned(tester);

      final textTheme =
          Theme.of(tester.element(find.byType(ChurchCard))).textTheme;
      expect(
        drawnStyle(tester, find.text('Nagytemplom')).fontSize,
        textTheme.titleMedium!.fontSize,
      );
    });

    testWidgets('the ink is the theme\'s own', (tester) async {
      await pumpDesigned(tester);

      final ink = tester.widget<InkWell>(
        find
            .descendant(of: find.byType(Card), matching: find.byType(InkWell))
            .first,
      );
      expect(ink.splashColor, isNull);
    });

    testWidgets('keeps 16 inside its edge and 8 between the chips (KO1, TK2)', (
      tester,
    ) async {
      await pumpDesigned(tester);

      final card = tester.getRect(
        find
            .descendant(of: find.byType(Card), matching: find.byType(Material))
            .first,
      );
      final name = tester.getRect(find.text('Nagytemplom'));
      expect(name.left - card.left, Spacing.l);
      expect(name.top - card.top, Spacing.l);
      final first = tester.getRect(find.byType(TimeChip).first);
      final second = tester.getRect(find.byType(TimeChip).last);
      expect(first.left - card.left, Spacing.l);
      expect(second.left - first.right, Spacing.s);
    });

    testWidgets('the time is its strongest text (TI3)', (tester) async {
      await pumpDesigned(tester);

      final time = drawnStyle(tester, find.text('08:00'));
      for (final text
          in find
              .descendant(
                of: find.byType(ChurchCard),
                matching: find.byType(Text),
              )
              .evaluate()) {
        final style = drawnStyle(tester, find.byWidget(text.widget).first);
        final label = (text.widget as Text).data;
        expect(
          style.fontSize,
          lessThanOrEqualTo(time.fontSize!),
          reason: label,
        );
        expect(
          style.fontWeight!.value,
          lessThanOrEqualTo(time.fontWeight!.value),
          reason: label,
        );
      }
    });

    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      for (final width in eh4Widths) {
        for (final textScale in eh4TextScales) {
          testWidgets(
            'fits $width dp at text scale $textScale on $platform (EH4)',
            (tester) async {
              await pumpDesigned(
                tester,
                entry: _entry(
                  masses: [
                    for (var hour = 6; hour < 20; hour++) _mass(hour, 30),
                  ],
                ),
                platform: platform,
                width: width,
                textScale: textScale,
                failure: ApiFailure.noConnection,
              );

              expect(tester.takeException(), isNull);
            },
            // The card's fixed height cannot hold a doubled text size; the
            // height comes from the content with #67.
            skip: textScale > 1,
          );
        }
      }
    }
  });
}
