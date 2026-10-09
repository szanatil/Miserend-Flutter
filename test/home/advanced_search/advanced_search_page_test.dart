import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/home/advanced_search/advanced_search_loader.dart';
import 'package:miserend/home/advanced_search/advanced_search_page.dart';
import 'package:miserend/location_provider.dart';
import 'package:miserend/theme/miserend_theme.dart';
import 'package:miserend/theme/tokens.dart';
import 'package:provider/provider.dart';

import '../../database/fake_favorites_service.dart';
import '../../fake_location_provider.dart';
import '../../theme/theme_harness.dart';
import 'fake_advanced_search_loader.dart';

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

  group('fits (EH4)', () {
    for (final width in [320.0, 430.0]) {
      for (final textScale in [1.0, 2.0]) {
        testWidgets('at $width dp and text scale $textScale', (tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1.0;
          tester.platformDispatcher.textScaleFactorTestValue = textScale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          await pumpPage(
            tester,
            FakeAdvancedSearchLoader([resultPage(const [])]),
          );
          expect(tester.takeException(), isNull, reason: 'the conditions');

          await tester.enterText(field('Település'), 'Sehol');
          await search(tester);
          expect(find.text('Nincs találat'), findsOneWidget);
          expect(tester.takeException(), isNull, reason: 'no church found');
        });
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
