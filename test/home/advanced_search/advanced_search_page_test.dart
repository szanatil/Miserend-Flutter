import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:miserend/database/cache/cached_mass.dart';
import 'package:miserend/database/cache/church_list_entry.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/home/advanced_search/advanced_search_loader.dart';
import 'package:miserend/home/advanced_search/advanced_search_page.dart';
import 'package:miserend/location_provider.dart';
import 'package:miserend/mass_kind.dart';
import 'package:miserend/theme/miserend_theme.dart';
import 'package:miserend/theme/tokens.dart';
import 'package:miserend/widgets/card_columns.dart';
import 'package:provider/provider.dart';

import '../../database/fake_favorites_service.dart';
import '../../fake_location_provider.dart';
import '../../theme/theme_harness.dart';
import 'fake_advanced_search_loader.dart';

/// A common name that takes a card's line twice over on a phone.
const String _longCommonName =
    'Alsóvárosi templom, Ferences templom, Barátok temploma, Szent Miklós';

/// A Wednesday morning; its Sunday is 2026-09-20.
final DateTime _now = DateTime(2026, 9, 16, 10, 0);

final PositionFound _found = PositionFound(
  Position(
    latitude: 46.07,
    longitude: 18.23,
    timestamp: _now,
    accuracy: 10,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  ),
);

void main() {
  Future<void> pumpPage(
    WidgetTester tester,
    FakeAdvancedSearchLoader loader, {
    LocationProvider? location,
    String initialName = '',
    VoidCallback? onClose,
    Brightness brightness = Brightness.light,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<FavoritesService>.value(
        value: FakeFavoritesService(const []),
        child: MaterialApp(
          theme: miserendTheme(brightness),
          home: AdvancedSearchPage(
            initialName: initialName,
            onClose: onClose ?? () {},
            loader: loader,
            location: location ?? FakeLocationProvider(),
            clock: () => _now,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  Future<void> search(WidgetTester tester) async {
    // The button follows the fields on the next frame.
    await tester.pump();
    final button = find.widgetWithText(FilledButton, 'Keresés');
    // Below the fold on a narrow screen with large text.
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  FilledButton searchButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Keresés'));

  const explanation =
      'Adj meg nevet vagy települést: a helyzeted nem ismert, így a '
      'környékeden nem kereshetünk.';

  group('the search button', () {
    testWidgets('with no name, no city and no position, is off and says why', (
      tester,
    ) async {
      await pumpPage(tester, FakeAdvancedSearchLoader(const []));

      expect(searchButton(tester).onPressed, isNull);
      expect(find.text(explanation), findsOneWidget);
    });

    testWidgets('a city turns it on', (tester) async {
      await pumpPage(tester, FakeAdvancedSearchLoader(const []));

      await tester.enterText(field('Település'), 'Pécs');
      await tester.pump();

      expect(searchButton(tester).onPressed, isNotNull);
      expect(find.text(explanation), findsNothing);
    });

    testWidgets('a known position turns it on with nothing typed', (
      tester,
    ) async {
      await pumpPage(
        tester,
        FakeAdvancedSearchLoader(const []),
        location: FakeLocationProvider([_found]),
      );

      expect(searchButton(tester).onPressed, isNotNull);
    });
  });

  testWidgets('opens with the search bar\'s text as the name', (tester) async {
    await pumpPage(
      tester,
      FakeAdvancedSearchLoader(const []),
      initialName: 'Mátyás',
    );

    expect(
      tester.widget<TextField>(field('Templom neve')).controller!.text,
      'Mátyás',
    );
  });

  testWidgets('the back arrow closes the page', (tester) async {
    var closed = 0;
    await pumpPage(
      tester,
      FakeAdvancedSearchLoader(const []),
      onClose: () => closed++,
    );

    await tester.tap(find.byType(BackButton));

    expect(closed, 1);
  });

  group('after a search', () {
    testWidgets('the conditions fold into a summary above the results', (
      tester,
    ) async {
      final loader = FakeAdvancedSearchLoader([
        resultPage([churchEntry(1, name: 'Pécsi székesegyház')]),
      ]);
      await pumpPage(tester, loader);

      await tester.enterText(field('Település'), 'Pécs');
      await tester.tap(find.text('Vasárnap'));
      await tester.pump();
      await tester.tap(find.text('Egész nap'));
      await tester.pump();
      await search(tester);

      expect(find.text('Pécs · vasárnap 8–12'), findsOneWidget);
      expect(find.text('Pécsi székesegyház'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Keresés'), findsNothing);
      final (criteria, page) = loader.asked.single;
      expect(page, 0);
      expect(criteria.city, 'Pécs');
      expect(criteria.day, DateTime(2026, 9, 20));
      expect(criteria.from, const TimeOfDay(hour: 8, minute: 0));
      expect(criteria.until, const TimeOfDay(hour: 12, minute: 0));
    });

    testWidgets('scrolled, then unfolded and folded again, the list is where '
        'it was', (tester) async {
      await pumpPage(
        tester,
        FakeAdvancedSearchLoader([
          resultPage([for (var i = 1; i <= 20; i++) churchEntry(i)]),
        ]),
      );
      await tester.enterText(field('Település'), 'Pécs');
      await search(tester);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(find.text('Templom 1'), findsNothing);

      await tester.tap(find.text('Pécs'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Összecsukás'));
      await tester.pumpAndSettle();

      expect(find.text('Templom 1'), findsNothing);
    });

    testWidgets('folding the conditions without a search brings the last '
        'search\'s back', (tester) async {
      final loader = FakeAdvancedSearchLoader([
        resultPage([churchEntry(1)]),
      ]);
      await pumpPage(tester, loader);
      await tester.enterText(field('Település'), 'Pécs');
      await search(tester);

      await tester.tap(find.text('Pécs'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Település'), 'Szeged');
      await tester.tap(find.byTooltip('Összecsukás'));
      await tester.pumpAndSettle();

      expect(find.text('Pécs'), findsOneWidget);
      expect(find.text('Templom 1'), findsOneWidget);
      expect(loader.asked, hasLength(1));
      await tester.tap(find.text('Pécs'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field('Település')).controller!.text,
        'Pécs',
      );
    });

    testWidgets('no church found says so, and offers the conditions again', (
      tester,
    ) async {
      await pumpPage(tester, FakeAdvancedSearchLoader([resultPage(const [])]));
      await tester.enterText(field('Település'), 'Sehol');
      await search(tester);

      expect(find.text('Nincs találat'), findsOneWidget);
      await tester.tap(find.text('Feltételek módosítása'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Keresés'), findsOneWidget);
    });

    for (final brightness in Brightness.values) {
      testWidgets('in $brightness, offering the conditions again is a tonal '
          'button, the only filled one (KO8, KO9)', (tester) async {
        await pumpPage(
          tester,
          FakeAdvancedSearchLoader([resultPage(const [])]),
          brightness: brightness,
        );
        await tester.enterText(field('Település'), 'Sehol');
        await search(tester);

        expect(find.byType(OutlinedButton), findsNothing);
        expect(find.byType(FilledButton), findsOneWidget);
        final again = find.widgetWithText(
          FilledButton,
          'Feltételek módosítása',
        );
        expect(
          tester
              .widget<Material>(
                find.descendant(of: again, matching: find.byType(Material)),
              )
              .color,
          miserendTheme(brightness).colorScheme.secondaryContainer,
        );
      });
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('in $brightness, the conditions and the results meet the '
        'accessibility guidelines (AM1, AM3, AM5)', (tester) async {
      await pumpPage(
        tester,
        FakeAdvancedSearchLoader([
          resultPage([for (var i = 1; i <= 3; i++) churchEntry(i)]),
          resultPage(const []),
        ]),
        brightness: brightness,
      );
      await expectAccessibilityGuidelines(tester);

      await tester.enterText(field('Település'), 'Pécs');
      await search(tester);
      expect(find.text('Templom 1'), findsOneWidget);
      await expectAccessibilityGuidelines(tester);
    }, variant: eh4Platforms);
  }

  group('fits (EH4)', () {
    for (final width in eh4Widths) {
      for (final textScale in eh4TextScales) {
        testWidgets('at $width dp and text scale $textScale', (tester) async {
          setScreen(tester, Size(width, 800), textScale: textScale);

          await pumpPage(
            tester,
            FakeAdvancedSearchLoader([
              resultPage([
                for (var i = 1; i <= 3; i++)
                  churchEntry(i, commonName: _longCommonName),
              ]),
              resultPage(const []),
            ]),
          );
          expect(tester.takeException(), isNull, reason: 'the conditions');

          await tester.enterText(field('Település'), 'Pécs');
          await search(tester);
          expect(find.text('Templom 1'), findsOneWidget);
          expect(tester.takeException(), isNull, reason: 'the results');
        }, variant: eh4Platforms);

        testWidgets('with no church found at $width dp and text scale '
            '$textScale', (tester) async {
          setScreen(tester, Size(width, 800), textScale: textScale);
          await pumpPage(
            tester,
            FakeAdvancedSearchLoader([resultPage(const [])]),
          );

          await tester.enterText(field('Település'), 'Sehol');
          await search(tester);
          expect(find.text('Nincs találat'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }, variant: eh4Platforms);
      }
    }
  });

  testWidgets('fits a phone on its side (EL5)', (tester) async {
    setScreen(tester, const Size(640, 320), textScale: 2);
    await pumpPage(
      tester,
      FakeAdvancedSearchLoader([
        resultPage([churchEntry(1, commonName: _longCommonName)]),
      ]),
    );
    expect(tester.takeException(), isNull, reason: 'the conditions');

    await tester.enterText(field('Település'), 'Pécs');
    await search(tester);
    expect(find.text('Templom 1'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'the results');
  }, variant: eh4Platforms);

  for (final width in const [el3Width, threeColumnWidth]) {
    testWidgets('on a $width dp screen the conditions and the summary are '
        'at most 640 wide and centred (EL3)', (tester) async {
      setScreen(tester, Size(width, 800));
      await pumpPage(
        tester,
        FakeAdvancedSearchLoader([
          resultPage([churchEntry(1)]),
        ]),
      );

      expectCentredContent(
        tester,
        find.ancestor(of: find.text('Feltételek'), matching: find.byType(Card)),
        screenWidth: width,
      );

      await tester.enterText(field('Település'), 'Pécs');
      await search(tester);

      if (width == el3Width) {
        expectCentredContent(
          tester,
          find.ancestor(
            of: find.text('Templom 1'),
            matching: find.byType(Card),
          ),
        );
      }
      expectCentredContent(
        tester,
        // The summary's surface, inside the margin that centres it.
        find
            .ancestor(of: find.text('Pécs'), matching: find.byType(InkWell))
            .first,
        screenWidth: width,
      );
    });
  }

  group('in columns (EL3)', () {
    Future<void> searchWide(
      WidgetTester tester,
      double width,
      FakeAdvancedSearchLoader loader, {
      double height = 1200,
      double textScale = 1,
      Brightness brightness = Brightness.light,
    }) async {
      setScreen(tester, Size(width, height), textScale: textScale);
      await pumpPage(tester, loader, brightness: brightness);
      await tester.enterText(field('Település'), 'Pécs');
      await search(tester);
    }

    Rect cardOf(WidgetTester tester, int id) => tester.getRect(
      find.ancestor(of: find.text('Templom $id'), matching: find.byType(Card)),
    );

    /// The first row's cards stand side by side, as tall as each other.
    void expectFirstRowLevel(WidgetTester tester, int columns) {
      final cards = [for (var i = 1; i <= columns; i++) cardOf(tester, i)];
      for (final card in cards.skip(1)) {
        expect(card.left, greaterThan(cards.first.right));
        expect(card.top, cards.first.top);
        expect(card.height, cards.first.height);
      }
    }

    testWidgets('on a 1300 dp screen the results stand three to a row, as '
        'tall as each other', (tester) async {
      await searchWide(
        tester,
        threeColumnWidth,
        FakeAdvancedSearchLoader([
          resultPage([
            churchEntry(1, commonName: _longCommonName),
            churchEntry(2),
            churchEntry(3),
            churchEntry(4),
          ]),
        ]),
      );

      final cards = [for (var i = 1; i <= 4; i++) cardOf(tester, i)];
      // 8 between the cards (TK2).
      expect(cards[1].left - cards[0].right, CardRow.listGap);
      expect(cards[2].left - cards[1].right, CardRow.listGap);
      expect([cards[1].top, cards[2].top], everyElement(cards[0].top));
      expect([cards[1].height, cards[2].height], everyElement(cards[0].height));
      expect(cards[3].left, cards[0].left);
      expect(cards[3].top, cards[0].bottom);
      expect(cards[3].width, cards[0].width);
      expect(tester.takeException(), isNull);
    });

    testWidgets('on a 1000 dp screen the results stand two to a row, as tall '
        'as each other', (tester) async {
      await searchWide(
        tester,
        twoColumnWidth,
        FakeAdvancedSearchLoader([
          resultPage([
            churchEntry(1, commonName: _longCommonName),
            churchEntry(2),
            churchEntry(3),
          ]),
        ]),
      );

      expectFirstRowLevel(tester, 2);
      expect(cardOf(tester, 3).left, cardOf(tester, 1).left);
      expect(cardOf(tester, 3).top, cardOf(tester, 1).bottom);
    });

    testWidgets('the count names the last card seen whole', (tester) async {
      await searchWide(
        tester,
        twoColumnWidth,
        FakeAdvancedSearchLoader([
          resultPage([
            for (var i = 1; i <= 40; i++)
              churchEntry(i, commonName: i % 3 == 0 ? _longCommonName : null),
          ]),
        ]),
        height: 800,
      );

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
      await tester.pump();
      await tester.pump();

      final viewport = tester.getRect(find.byType(CustomScrollView));
      var lastWhole = 0;
      for (var i = 1; i <= 40; i++) {
        final card = find.text('Templom $i');
        if (card.evaluate().isEmpty) continue;
        if (cardOf(tester, i).bottom <= viewport.bottom) lastWhole = i;
      }
      expect(lastWhole, greaterThan(2));
      expect(lastWhole.isEven, isTrue, reason: 'a whole row');
      expect(find.text('$lastWhole / 40 találat'), findsOneWidget);
    });

    testWidgets('scrolled to the end, the count takes in a short last row', (
      tester,
    ) async {
      await searchWide(
        tester,
        threeColumnWidth,
        FakeAdvancedSearchLoader([
          resultPage([for (var i = 1; i <= 31; i++) churchEntry(i)]),
        ]),
        height: 800,
      );

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -6000));
      await tester.pump();
      await tester.pump();

      expect(find.text('31 / 31 találat'), findsOneWidget);
    });

    testWidgets('on a 2000 dp screen the three columns are each at most 640 '
        'wide, the rest empty on both sides', (tester) async {
      await searchWide(
        tester,
        2000,
        FakeAdvancedSearchLoader([
          resultPage([for (var i = 1; i <= 3; i++) churchEntry(i)]),
        ]),
      );

      final cards = [for (var i = 1; i <= 3; i++) cardOf(tester, i)];
      expect(cards.map((card) => card.width), everyElement(640));
      expect((cards[0].left + cards[2].right) / 2, 1000);
    });

    testWidgets('scrolling towards the end asks for the next page', (
      tester,
    ) async {
      final loader = FakeAdvancedSearchLoader([
        resultPage(
          [for (var i = 1; i <= 30; i++) churchEntry(i)],
          hasMore: true,
          found: 35,
        ),
        resultPage([for (var i = 31; i <= 35; i++) churchEntry(i)], found: 35),
      ]);
      await searchWide(tester, threeColumnWidth, loader, height: 800);
      expect(loader.asked.map((a) => a.$2), [0]);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
      await tester.pumpAndSettle();

      expect(loader.asked.map((a) => a.$2), [0, 1]);
      expect(find.text('Nincs több találat · 35 találat'), findsOneWidget);
    });

    testWidgets('scrolled, then unfolded and folded again, the list is where '
        'it was', (tester) async {
      await searchWide(
        tester,
        threeColumnWidth,
        FakeAdvancedSearchLoader([
          resultPage([for (var i = 1; i <= 60; i++) churchEntry(i)]),
        ]),
        height: 800,
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(find.text('Templom 1'), findsNothing);

      await tester.tap(find.text('Pécs'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Összecsukás'));
      await tester.pumpAndSettle();

      expect(find.text('Templom 1'), findsNothing);
    });

    for (final brightness in Brightness.values) {
      for (final width in const [twoColumnWidth, threeColumnWidth]) {
        for (final textScale in eh4TextScales) {
          testWidgets('fits, the rows as tall as each other, in $brightness '
              'at $width dp and text scale $textScale (EH3, EH4)', (
            tester,
          ) async {
            await searchWide(
              tester,
              width,
              FakeAdvancedSearchLoader([
                resultPage([
                  for (var i = 1; i <= 5; i++)
                    churchEntry(
                      i,
                      commonName: i.isOdd ? _longCommonName : null,
                    ),
                ]),
              ]),
              height: 800,
              textScale: textScale,
              brightness: brightness,
            );

            expect(tester.takeException(), isNull);
            expectFirstRowLevel(tester, width == twoColumnWidth ? 2 : 3);
          }, variant: eh4Platforms);
        }
      }
    }
  });

  group('pages', () {
    testWidgets('scrolling towards the end asks for the next page', (
      tester,
    ) async {
      final loader = FakeAdvancedSearchLoader([
        resultPage(
          [for (var i = 1; i <= 20; i++) churchEntry(i)],
          hasMore: true,
          found: 25,
        ),
        resultPage([for (var i = 21; i <= 25; i++) churchEntry(i)], found: 25),
      ]);
      await pumpPage(tester, loader);
      await tester.enterText(field('Település'), 'Pécs');
      await search(tester);
      expect(loader.asked.map((a) => a.$2), [0]);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -3600));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
      await tester.pumpAndSettle();

      expect(loader.asked.map((a) => a.$2), [0, 1]);
      expect(find.text('Nincs több találat · 25 találat'), findsOneWidget);
    });

    testWidgets('a page that finds too few to fill the screen asks for the '
        'next on its own', (tester) async {
      final loader = FakeAdvancedSearchLoader([
        resultPage([churchEntry(1)], hasMore: true, foundIsFinal: false),
        resultPage(const [], hasMore: true, found: 1, foundIsFinal: false),
        resultPage([churchEntry(2)], found: 2),
      ]);
      await pumpPage(tester, loader);
      await tester.enterText(field('Település'), 'Pécs');
      await search(tester);

      expect(loader.asked.map((a) => a.$2), [0, 1, 2]);
      expect(find.text('Templom 2'), findsOneWidget);
    });

    testWidgets('while pages are left with a day, the count says more may '
        'come', (tester) async {
      final loader = FakeAdvancedSearchLoader([
        resultPage(
          [for (var i = 1; i <= 20; i++) churchEntry(i)],
          hasMore: true,
          foundIsFinal: false,
        ),
      ]);
      await pumpPage(tester, loader);
      await tester.enterText(field('Település'), 'Pécs');
      await tester.tap(find.text('Ma'));
      await search(tester);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump();

      expect(find.textContaining(RegExp(r'^\d+ / 20\+ találat$')), findsOne);
    });

    for (final textScale in [1.0, 2.0]) {
      testWidgets('the count names the last card seen whole at text scale '
          '$textScale, however tall the cards', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpPage(
          tester,
          FakeAdvancedSearchLoader([
            resultPage([
              for (var i = 1; i <= 20; i++)
                churchEntry(i, commonName: i.isEven ? _longCommonName : null),
            ]),
          ]),
        );
        await tester.enterText(field('Település'), 'Pécs');
        await search(tester);

        await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
        await tester.pump();
        // The count reads the cards once they are laid out where the scroll
        // put them, and shows it on the next frame.
        await tester.pump();

        final viewport = tester.getRect(find.byType(CustomScrollView));
        var lastWhole = 0;
        for (var i = 1; i <= 20; i++) {
          final card = find.text('Templom $i');
          if (card.evaluate().isEmpty) continue;
          final rect = tester.getRect(
            find.ancestor(of: card, matching: find.byType(Card)).first,
          );
          if (rect.bottom <= viewport.bottom) lastWhole = i;
        }
        expect(lastWhole, greaterThan(1));
        expect(find.text('$lastWhole / 20 találat'), findsOneWidget);
      });
    }

    for (final brightness in Brightness.values) {
      testWidgets('in $brightness, the results stand on the surface and the '
          'count on the inverse surface (SZ5, KO20)', (tester) async {
        await pumpPage(
          tester,
          FakeAdvancedSearchLoader([
            resultPage([for (var i = 1; i <= 20; i++) churchEntry(i)]),
          ]),
          brightness: brightness,
        );
        await tester.enterText(field('Település'), 'Pécs');
        await search(tester);
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
        await tester.pump();

        final scheme = miserendTheme(brightness).colorScheme;
        final ground = tester.widget<Material>(
          find
              .descendant(
                of: find.byType(Scaffold),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(ground.color, scheme.surface);

        final count = find.textContaining(RegExp(r'^\d+ / 20 találat$'));
        final box =
            tester
                    .widget<DecoratedBox>(
                      find
                          .ancestor(
                            of: count,
                            matching: find.byType(DecoratedBox),
                          )
                          .first,
                    )
                    .decoration
                as ShapeDecoration;
        expect(box.color, scheme.inverseSurface);
        expect(drawnStyle(tester, count).color, scheme.onInverseSurface);
      });
    }

    testWidgets('the count is a full-round pill, labelLarge with tabular '
        'figures (KO20)', (tester) async {
      await pumpPage(
        tester,
        FakeAdvancedSearchLoader([
          resultPage([for (var i = 1; i <= 20; i++) churchEntry(i)]),
        ]),
      );
      await tester.enterText(field('Település'), 'Pécs');
      await search(tester);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump();

      final count = find.textContaining(RegExp(r'^\d+ / 20 találat$'));
      final pill = find.ancestor(
        of: count,
        matching: find.byType(DecoratedBox),
      );
      expect(
        (tester.widget<DecoratedBox>(pill.first).decoration as ShapeDecoration)
            .shape,
        Radii.full,
      );
      expect(
        tester
            .widget<Padding>(
              find.ancestor(of: count, matching: find.byType(Padding)).first,
            )
            .padding,
        const EdgeInsets.symmetric(horizontal: Spacing.l, vertical: Spacing.s),
      );
      final style = drawnStyle(tester, count);
      expect(
        style.fontSize,
        Theme.of(tester.element(count)).textTheme.labelLarge!.fontSize,
      );
      expect(style.fontFeatures, [const FontFeature.tabularFigures()]);
    });
  });

  test('a picked date reads as the month\'s short name and the day', () {
    expect(shortDate(DateTime(2026, 10, 4)), 'okt. 4.');
  });

  test('the criteria need a name, a city or a position', () {
    expect(const AdvancedSearchCriteria(city: '  ').canSearch, isFalse);
    expect(const AdvancedSearchCriteria(language: 'va').canSearch, isFalse);
    expect(const AdvancedSearchCriteria(name: 'x').canSearch, isTrue);
  });

  testWidgets(
    'the whole-day switch is the platform\'s own, and taps '
    'lightly on iOS (PL2)',
    (tester) async {
      final haptics = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pumpPage(tester, FakeAdvancedSearchLoader([]));

      await tester.tap(find.text('Vasárnap'));
      await tester.pump();
      final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
      // Switch.adaptive draws the iOS switch itself rather than building a
      // CupertinoSwitch: its track is iOS's 51 × 31 rather than M3's
      // 52 × 32, and switched on it is the selection colour on both
      // platforms (SZ4).
      expect(
        tester.renderObject(find.byType(Switch)),
        paints..rrect(
          rrect:
              isIOS
                  ? RRect.fromLTRBR(
                    4.5,
                    4.5,
                    55.5,
                    35.5,
                    const Radius.circular(15.5),
                  )
                  : RRect.fromLTRBR(4, 4, 56, 36, const Radius.circular(16)),
          color: schemeOf(Brightness.light).primary,
        ),
      );
      await tester.tap(find.text('Egész nap'));
      await tester.pump();

      expect(
        haptics.map((call) => call.arguments),
        isIOS ? ['HapticFeedbackType.lightImpact'] : isEmpty,
      );
    },
    variant: TargetPlatformVariant(const {
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  group('the occasion categories', () {
    const labels = ['Mise', 'Szentségimádás', 'Gyóntatás', 'Egyéb'];

    Finder chip(String label) => find.widgetWithText(FilterChip, label);

    bool selected(WidgetTester tester, String label) =>
        tester.widget<FilterChip>(chip(label)).selected;

    Future<void> tapChip(WidgetTester tester, String label) async {
      await tester.ensureVisible(chip(label));
      await tester.pump();
      await tester.tap(chip(label));
      await tester.pump();
    }

    /// Opens the page with a city typed and Sunday chosen.
    Future<FakeAdvancedSearchLoader> onSunday(
      WidgetTester tester, {
      Brightness brightness = Brightness.light,
    }) async {
      final loader = FakeAdvancedSearchLoader([
        resultPage([churchEntry(1)]),
      ]);
      await pumpPage(tester, loader, brightness: brightness);
      await tester.enterText(field('Település'), 'Pécs');
      // Below the fold on a narrow screen with large text.
      final sunday = find.widgetWithText(ChoiceChip, 'Vasárnap');
      await tester.ensureVisible(sunday);
      await tester.pumpAndSettle();
      await tester.tap(sunday);
      await tester.pump();
      return loader;
    }

    testWidgets('stand only beside a day, as the time window does', (
      tester,
    ) async {
      await pumpPage(tester, FakeAdvancedSearchLoader(const []));

      expect(find.byType(FilterChip), findsNothing);
    });

    testWidgets('open with only Mise chosen, which searches for masses and '
        'leaves the summary as it was', (tester) async {
      final loader = await onSunday(tester);

      expect(
        [for (final label in labels) selected(tester, label)],
        [true, false, false, false],
      );
      await search(tester);

      expect(find.text('Pécs · vasárnap'), findsOneWidget);
      expect(loader.asked.single.$1.categories, {OccasionCategory.mass});
    });

    testWidgets('the last one chosen cannot be turned off', (tester) async {
      await onSunday(tester);

      await tapChip(tester, 'Mise');

      expect(selected(tester, 'Mise'), isTrue);
    });

    testWidgets('chosen apart from the default, are searched for and named in '
        'the summary', (tester) async {
      final loader = await onSunday(tester);

      await tapChip(tester, 'Szentségimádás');
      await tapChip(tester, 'Gyóntatás');
      await tapChip(tester, 'Mise');
      await search(tester);

      expect(
        find.text('Pécs · vasárnap · szentségimádás, gyóntatás'),
        findsOneWidget,
      );
      expect(loader.asked.single.$1.categories, {
        OccasionCategory.adoration,
        OccasionCategory.confession,
      });
    });

    testWidgets('all four chosen, the summary says every occasion', (
      tester,
    ) async {
      final loader = await onSunday(tester);

      for (final label in labels.skip(1)) {
        await tapChip(tester, label);
      }
      await search(tester);

      expect(find.text('Pécs · vasárnap · minden alkalom'), findsOneWidget);
      expect(
        loader.asked.single.$1.categories,
        OccasionCategory.values.toSet(),
      );
    });

    testWidgets('the results\' cards show every occasion the loader found, '
        'adoration too', (tester) async {
      await pumpPage(
        tester,
        FakeAdvancedSearchLoader([
          resultPage([
            ChurchListEntry(
              id: 1,
              name: 'Templom 1',
              commonName: null,
              city: 'Pécs',
              lat: 46.07,
              lon: 18.23,
              photo: null,
              masses: [
                CachedMass(
                  id: null,
                  apiMassId: null,
                  churchId: 1,
                  time: DateTime(2026, 9, 20, 10, 30),
                  info: 'Római katolikus Szentségimádás',
                  source: MassSource.dailyList,
                ),
              ],
            ),
          ]),
        ]),
      );
      await tester.enterText(field('Település'), 'Pécs');
      await tester.tap(find.text('Vasárnap'));
      await tester.pump();
      await tapChip(tester, 'Szentségimádás');
      await search(tester);

      expect(find.text('10:30'), findsOneWidget);
    });

    for (final brightness in Brightness.values) {
      for (final width in eh4Widths) {
        for (final textScale in eh4TextScales) {
          testWidgets('in $brightness at $width dp and text scale $textScale, '
              'fit, wrapping, each with a 48 dp target (EL2, AM3)', (
            tester,
          ) async {
            setScreen(tester, Size(width, 800), textScale: textScale);

            await onSunday(tester, brightness: brightness);

            expect(tester.takeException(), isNull);
            for (final label in labels) {
              await tester.ensureVisible(chip(label));
              await tester.pump();
              final size = tester.getSize(chip(label));
              expect(size.height, greaterThanOrEqualTo(48), reason: label);
              expect(size.width, greaterThanOrEqualTo(48), reason: label);
              expect(
                tester.getRect(chip(label)).right,
                lessThanOrEqualTo(width),
                reason: label,
              );
            }
            // The search button, just turned on, fades into its colour.
            await tester.pumpAndSettle();
            await expectAccessibilityGuidelines(tester);
          }, variant: eh4Platforms);
        }
      }
    }
  });

  group('the time window', () {
    /// Picks [hour] o'clock in the [field]'s M3 time picker.
    Future<void> pickHour(WidgetTester tester, String field, int hour) async {
      await tester.tap(find.widgetWithText(InputDecorator, field));
      await tester.pumpAndSettle();
      // The dial's numbers are painted, so the hour is typed instead.
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(TimePickerDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), '$hour');
      await tester.enterText(fields.at(1), '00');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kész'));
      await tester.pumpAndSettle();
    }

    Future<void> openWindow(WidgetTester tester) async {
      tester.view.physicalSize = const Size(430, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpPage(tester, FakeAdvancedSearchLoader([]));
      await tester.tap(find.text('Vasárnap'));
      await tester.pump();
      await tester.tap(find.text('Egész nap'));
      await tester.pumpAndSettle();
      expect(find.text('8:00'), findsOneWidget);
      expect(find.text('12:00'), findsOneWidget);
    }

    testWidgets('a start after the end moves the end along', (tester) async {
      await openWindow(tester);

      await pickHour(tester, '-tól', 15);

      expect(find.text('15:00'), findsNWidgets(2));
    });

    testWidgets('an end before the start moves the start along', (
      tester,
    ) async {
      await openWindow(tester);

      await pickHour(tester, '-ig', 6);

      expect(find.text('6:00'), findsNWidgets(2));
    });

    testWidgets('a start before the end leaves the end alone', (tester) async {
      await openWindow(tester);

      await pickHour(tester, '-tól', 10);

      expect(find.text('10:00'), findsOneWidget);
      expect(find.text('12:00'), findsOneWidget);
    });
  });
}
