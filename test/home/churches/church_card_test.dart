import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'package:miserend/widgets/card_columns.dart';
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

  group('screen reader (AM5)', () {
    SemanticsNode card(WidgetTester tester) => tester.getSemantics(
      find
          .descendant(
            of: find.byType(ChurchCard),
            matching: find.byType(MergeSemantics),
          )
          .first,
    );

    String? customAction(SemanticsNode node) {
      final ids = node.getSemanticsData().customSemanticsActionIds ?? [];
      return ids.isEmpty
          ? null
          : CustomSemanticsAction.getAction(ids.single)!.label;
    }

    testWidgets('reads the card as one unit: the masses, the church, the '
        'distance', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCard(
        tester,
        _entry(masses: [_mass(8, 0), _mass(18, 30)]),
        position: _position,
      );

      final node = card(tester);
      expect(node.mergeAllDescendantsIntoThisNode, isTrue);
      final label = node.getSemanticsData().label;
      expect(label, startsWith('8:00'));
      expect(label, contains('18:30'));
      expect(label, contains('Nagytemplom'));
      expect(label, contains('300 m'));
      expect(label.indexOf('18:30'), lessThan(label.indexOf('Nagytemplom')));
      expect(label.indexOf('Nagytemplom'), lessThan(label.indexOf('300 m')));
      expect(node.getSemanticsData().flagsCollection.isImage, isFalse);
      handle.dispose();
    });

    testWidgets('opens the church on a tap', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCard(tester, _entry());

      expect(
        card(tester).getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
      handle.dispose();
    });

    testWidgets('the heart is an action of the card, named for what it does', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpCard(tester, _entry());
      final wasFavorite = favorites.isFavorite(1);
      String name(bool favorite) =>
          favorite ? 'Törlés a kedvencek közül' : 'Kedvencekhez';

      final node = card(tester);
      expect(customAction(node), name(wasFavorite));
      node.owner!.performAction(
        node.id,
        SemanticsAction.customAction,
        node.getSemanticsData().customSemanticsActionIds!.single,
      );
      for (var i = 0; i < 400 && favorites.isFavorite(1) == wasFavorite; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
      }
      await tester.pump();

      expect(favorites.isFavorite(1), !wasFavorite);
      expect(customAction(card(tester)), name(!wasFavorite));
      handle.dispose();
    });
  });

  group('today\'s occasions, whatever their kind (#77)', () {
    CachedMass occasion(int hour, int minute, String info) => CachedMass(
      id: null,
      apiMassId: null,
      churchId: 1,
      time: DateTime(2026, 9, 15, hour, minute),
      info: info,
      source: MassSource.dailyList,
    );

    Future<void> pumpAt(
      WidgetTester tester,
      ChurchListEntry entry, {
      DateTime? now,
      double width = 400,
    }) => pumpThemed(
      tester,
      ChangeNotifierProvider<FavoritesService>.value(
        value: favorites,
        child: ChurchCard(
          entry: entry,
          clock: () => now ?? DateTime(2026, 9, 15, 12, 0),
        ),
      ),
      width: width,
    );

    testWidgets('an adoration alone today has its chip, and is read out', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpAt(
        tester,
        _entry(masses: [occasion(18, 0, 'Római katolikus Szentségimádás')]),
      );

      expect(find.byType(TimeChip), findsOneWidget);
      expect(find.text('18:00'), findsOneWidget);
      final label =
          tester
              .getSemantics(
                find
                    .descendant(
                      of: find.byType(ChurchCard),
                      matching: find.byType(MergeSemantics),
                    )
                    .first,
              )
              .getSemanticsData()
              .label;
      expect(label, startsWith('18:00'));
      handle.dispose();
    });

    testWidgets('masses and a confession stand in time order, in alike chips', (
      tester,
    ) async {
      await pumpAt(
        tester,
        _entry(
          masses: [
            occasion(8, 0, 'Római katolikus Szentmise'),
            occasion(17, 0, 'Római katolikus Gyóntatás'),
            occasion(18, 0, 'Római katolikus Szentmise'),
          ],
        ),
        width: 600,
      );

      final chips = tester.widgetList<TimeChip>(find.byType(TimeChip)).toList();
      expect(
        [for (final chip in chips) chip.time],
        const [
          TimeOfDay(hour: 8, minute: 0),
          TimeOfDay(hour: 17, minute: 0),
          TimeOfDay(hour: 18, minute: 0),
        ],
      );
      for (final chip in chips) {
        expect(chip.hasInfo, isFalse);
        expect(chip.onTap, isNull);
      }
    });

    testWidgets('a confession begun 5 minutes ago is going on (KO3)', (
      tester,
    ) async {
      await pumpAt(
        tester,
        _entry(masses: [occasion(17, 0, 'Római katolikus Gyóntatás')]),
        now: DateTime(2026, 9, 15, 17, 5),
      );

      expect(tester.widget<TimeChip>(find.byType(TimeChip)).ongoing, isTrue);
    });

    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      for (final brightness in Brightness.values) {
        for (final width in eh4Widths) {
          for (final textScale in eh4TextScales) {
            testWidgets('an adoration\'s chip stands where a mass\'s does, at '
                '$width dp, text scale $textScale, $brightness, on $platform '
                '(EH3, EH4)', (tester) async {
              Future<void> pump(CachedMass row) => pumpThemed(
                tester,
                ChangeNotifierProvider<FavoritesService>.value(
                  value: favorites,
                  child: ChurchCard(entry: _entry(masses: [row])),
                ),
                brightness: brightness,
                platform: platform,
                width: width,
                textScale: textScale,
              );

              await pump(occasion(18, 0, 'Római katolikus Szentmise'));
              final chip = tester.getRect(find.byType(TimeChip));
              final heart = tester.getTopLeft(find.byType(IconButton)).dy;

              await pump(occasion(18, 0, 'Római katolikus Szentségimádás'));

              expect(tester.takeException(), isNull);
              expect(tester.getRect(find.byType(TimeChip)), chip);
              expect(tester.getTopLeft(find.byType(IconButton)).dy, heart);
            });
          }
        }
      }
    }
  });

  group('the occasions\' descriptions (KO1, KO3)', () {
    final adoration = CachedMass(
      id: null,
      apiMassId: null,
      churchId: 1,
      time: DateTime(2026, 9, 15, 10, 30),
      info: 'Római katolikus Szentségimádás',
      source: MassSource.dailyList,
    );
    final mass = CachedMass(
      id: null,
      apiMassId: null,
      churchId: 1,
      time: DateTime(2026, 9, 15, 8, 0),
      info: 'Római katolikus Szentmise',
      source: MassSource.dailyList,
    );

    Future<void> pumpDescribed(
      WidgetTester tester,
      ChurchListEntry entry, {
      double width = 400,
      Brightness brightness = Brightness.light,
      TargetPlatform platform = TargetPlatform.android,
      double textScale = 1,
      List<NavigatorObserver> observers = const [],
    }) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<FavoritesService>.value(
          value: favorites,
          child: MaterialApp(
            theme: miserendTheme(brightness).copyWith(platform: platform),
            navigatorObservers: observers,
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
              child: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: width,
                    child: ChurchCard(entry: entry, describesOccasions: true),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    /// Every marked chip takes taps on at least 48 × 48: its button's
    /// semantics node is as large as the area it takes taps in.
    void expectTapTargets(WidgetTester tester, {bool anyShown = true}) {
      final handle = tester.ensureSemantics();
      final chips = find.byWidgetPredicate(
        (widget) => widget is TimeChip && widget.onTap != null,
      );
      if (anyShown) expect(chips, findsWidgets);
      for (final element in chips.evaluate()) {
        final size =
            tester.getSemantics(find.byWidget(element.widget)).rect.size;
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      handle.dispose();
    }

    TimeChip chipOf(WidgetTester tester, String time) => tester.widget(
      find.ancestor(of: find.text(time), matching: find.byType(TimeChip)),
    );

    testWidgets('an occasion with more to it than a mass has its chip marked, '
        'and a plain mass has not', (tester) async {
      await pumpDescribed(tester, _entry(masses: [mass, adoration]));

      expect(chipOf(tester, '10:30').hasInfo, isTrue);
      expect(chipOf(tester, '10:30').onTap, isNotNull);
      expect(chipOf(tester, '8:00').hasInfo, isFalse);
      expect(chipOf(tester, '8:00').onTap, isNull);
    });

    testWidgets('the marked chip opens the description, not the church', (
      tester,
    ) async {
      final pushed = <Route<dynamic>>[];
      await pumpDescribed(
        tester,
        _entry(masses: [mass, adoration]),
        observers: [_PushRecorder(pushed)],
      );
      pushed.clear();

      await tester.tap(find.text('10:30'));
      await tester.pumpAndSettle();

      expect(find.text('Római katolikus Szentségimádás'), findsOneWidget);
      expect(pushed.whereType<MaterialPageRoute<dynamic>>(), isEmpty);
    });

    testWidgets('the marked chip takes taps on 48 × 48 (AM3)', (tester) async {
      await pumpDescribed(tester, _entry(masses: [adoration]));

      expectTapTargets(tester);
    });

    testWidgets('the description is an action of the card (AM5)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpDescribed(tester, _entry(masses: [mass, adoration]));

      final node = tester.getSemantics(
        find
            .descendant(
              of: find.byType(ChurchCard),
              matching: find.byType(MergeSemantics),
            )
            .first,
      );
      final labels = [
        for (final id
            in node.getSemanticsData().customSemanticsActionIds ?? <int>[])
          CustomSemanticsAction.getAction(id)!.label,
      ];
      expect(labels, contains('10:30 leírása'));
      expect(
        labels.where((label) => label?.contains('8:00') ?? false),
        isEmpty,
      );
      handle.dispose();
    });

    testWidgets('other lists\' cards mark no chip', (tester) async {
      await pumpCard(
        tester,
        _entry(
          masses: [
            CachedMass(
              id: null,
              apiMassId: null,
              churchId: 1,
              time: DateTime(2026, 9, 15, 8, 0),
              info: 'Római katolikus Szentmise, Csendes',
              source: MassSource.dailyList,
            ),
          ],
        ),
      );

      expect(chipOf(tester, '8:00').hasInfo, isFalse);
      expect(chipOf(tester, '8:00').onTap, isNull);
    });

    for (final columns in [2, 3]) {
      testWidgets('in $columns columns, a card taller for a marked chip has '
          'its row as tall (EL3)', (tester) async {
        await pumpThemed(
          tester,
          ChangeNotifierProvider<FavoritesService>.value(
            value: favorites,
            child: CardRow.of(columns, [
              ChurchCard(
                entry: _entry(masses: [adoration]),
                describesOccasions: true,
              ),
              for (var i = 1; i < columns; i++)
                ChurchCard(
                  entry: _entry(masses: [mass]),
                  describesOccasions: true,
                ),
            ]),
          ),
          width: columns * 400 + (columns - 1) * CardRow.listGap,
        );

        expect(tester.takeException(), isNull);
        final heights = {
          for (final element in find.byType(Card).evaluate())
            tester.getSize(find.byWidget(element.widget)).height,
        };
        expect(heights, hasLength(1));
        final hearts = {
          for (final element in find.byType(IconButton).evaluate())
            tester.getTopLeft(find.byWidget(element.widget)).dy,
        };
        expect(hearts, hasLength(1));
      });
    }

    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      for (final brightness in Brightness.values) {
        for (final width in eh4Widths) {
          for (final textScale in eh4TextScales) {
            testWidgets('marked chips fit at $width dp, text scale '
                '$textScale, $brightness, on $platform (EH3, EH4)', (
              tester,
            ) async {
              await pumpDescribed(
                tester,
                _entry(
                  masses: [
                    for (var hour = 6; hour < 20; hour++)
                      CachedMass(
                        id: null,
                        apiMassId: null,
                        churchId: 1,
                        time: DateTime(2026, 9, 15, hour, 30),
                        info: 'Római katolikus Szentségimádás',
                        source: MassSource.dailyList,
                      ),
                  ],
                ),
                width: width,
                brightness: brightness,
                platform: platform,
                textScale: textScale,
              );

              expect(tester.takeException(), isNull);
              final photo = tester.getRect(find.byType(Image));
              for (final element in find.byType(TimeChip).evaluate()) {
                expect(
                  tester.getRect(find.byWidget(element.widget)).right,
                  lessThanOrEqualTo(photo.left),
                );
              }
              // A marked chip too wide for the line gives way to the „…"
              // one (EL2).
              expectTapTargets(tester, anyShown: false);
            });

            testWidgets('a marked chip takes taps on 48 × 48, or gives way '
                'to a plain one where it would leave no time on the line, at '
                '$width dp, text scale $textScale, $brightness, on $platform '
                '(AM3, TI3, EH3, EH4)', (tester) async {
              await pumpDescribed(
                tester,
                _entry(masses: [adoration]),
                width: width,
                brightness: brightness,
                platform: platform,
                textScale: textScale,
              );

              expect(tester.takeException(), isNull);
              expect(find.text('10:30'), findsOneWidget);
              // Only the narrowest phone at the largest text has no room for
              // the marker.
              final marked = !(width == eh4Widths.first && textScale == 2);
              expect(chipOf(tester, '10:30').hasInfo, marked);
              expectTapTargets(tester, anyShown: marked);
            });
          }
        }
      }
    }
  });

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
    });

    testWidgets('a long common name wraps rather than being cut off, and the '
        'card grows for it (EL2)', (tester) async {
      await pumpCard(tester, _entry(), width: 320);
      final oneLine = tester.getSize(find.byType(Card)).height;

      await pumpCard(tester, _entry(commonName: longCommonName), width: 320);

      expect(tester.takeException(), isNull);
      final common = tester.widget<Text>(find.text(longCommonName));
      expect(common.maxLines, isNull);
      expect(common.overflow, isNot(TextOverflow.ellipsis));
      expect(tester.getSize(find.byType(Card)).height, greaterThan(oneLine));
    });

    testWidgets('the mass chips and the heart stand at the same height for a '
        'short and a long name', (tester) async {
      final masses = [_mass(8, 0)];
      await pumpCard(tester, _entry(name: 'Rövid', masses: masses));
      final chip = tester.getTopLeft(find.byType(TimeChip));
      final heart = tester.getTopLeft(find.byType(IconButton));

      await pumpCard(tester, _entry(name: longName, masses: masses));

      expect(tester.getTopLeft(find.byType(TimeChip)).dy, chip.dy);
      expect(tester.getTopLeft(find.byType(IconButton)).dy, heart.dy);
    });

    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      for (final brightness in Brightness.values) {
        for (final width in eh4Widths) {
          for (final textScale in eh4TextScales) {
            testWidgets('a church without a mass today keeps the chips\' '
                'line: the line and the heart stand where they do with one, '
                'at $width dp, text scale $textScale, $brightness, on '
                '$platform (EH3, EH4)', (tester) async {
              Future<void> pump(ChurchListEntry entry) => pumpThemed(
                tester,
                ChangeNotifierProvider<FavoritesService>.value(
                  value: favorites,
                  child: ChurchCard(entry: entry),
                ),
                brightness: brightness,
                platform: platform,
                width: width,
                textScale: textScale,
              );

              await pump(_entry(masses: [_mass(8, 0)]));
              final line = tester.getTopLeft(find.byType(Divider)).dy;
              final heart = tester.getTopLeft(find.byType(IconButton)).dy;
              final height = tester.getSize(find.byType(Card)).height;

              await pump(_entry());

              expect(tester.takeException(), isNull);
              expect(find.byType(TimeChip), findsNothing);
              expect(tester.getTopLeft(find.byType(Divider)).dy, line);
              expect(tester.getTopLeft(find.byType(IconButton)).dy, heart);
              expect(tester.getSize(find.byType(Card)).height, height);
            });
          }
        }
      }
    }

    testWidgets('a card without a common name is as tall as one with a short '
        'one', (tester) async {
      await pumpCard(tester, _entry());
      final withCommonName = tester.getSize(find.byType(Card)).height;

      await pumpCard(tester, _entry(commonName: null));

      expect(tester.getSize(find.byType(Card)).height, withCommonName);
    });

    testWidgets('the photo runs the card\'s full height, whatever it is', (
      tester,
    ) async {
      await pumpCard(
        tester,
        _entry(name: longName, commonName: longCommonName),
        width: 320,
      );

      final surface = tester.getRect(
        find
            .descendant(of: find.byType(Card), matching: find.byType(Material))
            .first,
      );
      final photo = tester.getRect(find.byType(Image));
      expect(photo.top, surface.top);
      expect(photo.bottom, surface.bottom);
      expect(photo.right, surface.right);
    });

    group('in a row of cards (EL3)', () {
      Future<void> pumpRow(
        WidgetTester tester,
        List<ChurchListEntry> entries, {
        double columnWidth = 400,
        Brightness brightness = Brightness.light,
        TargetPlatform platform = TargetPlatform.android,
        double textScale = 1,
      }) => pumpThemed(
        tester,
        ChangeNotifierProvider<FavoritesService>.value(
          value: favorites,
          child: CardRow.of(entries.length, [
            for (final entry in entries)
              ChurchCard(entry: entry, position: _position),
          ]),
        ),
        brightness: brightness,
        platform: platform,
        width:
            entries.length * columnWidth +
            (entries.length - 1) * CardRow.listGap,
        textScale: textScale,
      );

      List<Rect> rects(WidgetTester tester, Finder finder) => [
        for (var i = 0; i < finder.evaluate().length; i++)
          tester.getRect(finder.at(i)),
      ];

      Finder surfaces() => find.descendant(
        of: find.byType(Card),
        matching: find.byWidgetPredicate(
          (widget) => widget is Material && widget.type == MaterialType.card,
        ),
      );

      void expectLevel(WidgetTester tester, int columns) {
        expect(tester.takeException(), isNull);
        final cards = rects(tester, surfaces());
        expect(cards, hasLength(columns));
        expect({for (final card in cards) card.height}, hasLength(1));
        expect({
          for (final line in rects(tester, find.byType(Divider))) line.top,
        }, hasLength(1));
        expect({
          for (final heart in rects(tester, find.byType(IconButton))) heart.top,
        }, hasLength(1));
        expect({
          for (final chip in rects(tester, find.byType(TimeChip))) chip.top,
        }, hasLength(1));
        final photos = rects(tester, find.byType(Image));
        for (final (index, card) in cards.indexed) {
          expect(photos[index].top, card.top);
          expect(photos[index].bottom, card.bottom);
        }
      }

      // Two cards with masses, one stretched and one not, so the chips can
      // be held level; the one between them has no mass.
      List<ChurchListEntry> mixed(int columns) => [
        _entry(masses: [_mass(8, 0)]),
        _entry(commonName: longCommonName),
        if (columns == 3) _entry(commonName: null, masses: [_mass(18, 0)]),
      ];

      for (final columns in [2, 3]) {
        testWidgets('in $columns columns the cards are as tall, and the '
            'chips, the line and the heart stand level, with and without '
            'masses and a long common name', (tester) async {
          await pumpRow(tester, mixed(columns));

          expectLevel(tester, columns);
        });
      }

      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        for (final brightness in Brightness.values) {
          for (final columnWidth in eh4Widths) {
            for (final textScale in eh4TextScales) {
              testWidgets(
                'the cards stand level at $columnWidth dp a column, '
                'text scale $textScale, $brightness, on $platform (EH3, EH4)',
                (tester) async {
                  await pumpRow(
                    tester,
                    mixed(3),
                    columnWidth: columnWidth,
                    brightness: brightness,
                    platform: platform,
                    textScale: textScale,
                  );

                  expectLevel(tester, 3);
                },
              );
            }
          }
        }
      }

      testWidgets('the extra room goes under the common name: the names keep '
          'to the top', (tester) async {
        await pumpRow(tester, [
          _entry(name: 'Rövid', commonName: 'Egy sor'),
          _entry(commonName: longCommonName),
        ]);

        final card = rects(tester, surfaces()).first;
        expect(tester.getTopLeft(find.text('Rövid')).dy - card.top, Spacing.l);
        expect(
          tester.getTopLeft(find.text('Egy sor')).dy,
          tester.getTopLeft(find.text(longCommonName)).dy,
        );
      });
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

      expect(find.text('8:00'), findsOneWidget);
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

        testWidgets('the card is the theme card, raised 1, outlined in dark '
            'mode only (KO1, MÉ1)', (tester) async {
          await pumpDesigned(tester, brightness: brightness);

          final surface = cardSurface(tester);
          expect(surface.color, scheme.surfaceContainerLow);
          expect(surface.elevation, 1);
          expect(
            surface.shape,
            RoundedRectangleBorder(
              borderRadius: const BorderRadius.all(Radius.circular(Radii.m)),
              side:
                  brightness == Brightness.dark
                      ? BorderSide(color: scheme.outlineVariant)
                      : BorderSide.none,
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
              of: find.text('8:00'),
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

      final time = drawnStyle(tester, find.text('8:00'));
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
          );
        }
      }
    }

    testWidgets('many masses at 320 dp and text scale 2.0 stay on one line, '
        'ending in a „…" chip (EL2)', (tester) async {
      await pumpDesigned(
        tester,
        entry: _entry(
          masses: [for (var hour = 6; hour < 20; hour++) _mass(hour, 30)],
        ),
        width: 320,
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
      final chips = find.byType(TimeChip);
      final tops = {
        for (final element in chips.evaluate())
          tester.getTopLeft(find.byWidget(element.widget)).dy,
      };
      expect(tops, hasLength(1));
      final last = chips.evaluate().last.widget;
      expect(
        find.descendant(of: find.byWidget(last), matching: find.text('…')),
        findsOneWidget,
      );
    });
  });
}

/// Records the routes pushed.
class _PushRecorder extends NavigatorObserver {
  _PushRecorder(this.pushed);

  final List<Route<dynamic>> pushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushed.add(route);
}
