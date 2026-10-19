import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/about/about_page.dart';
import 'package:miserend/about/church_of_the_day_loader.dart';
import 'package:miserend/database/cache/bootstrap_importer.dart';
import 'package:miserend/database/cache/church_details.dart';
import 'package:miserend/theme/miserend_theme.dart';
import 'package:miserend/widgets/feedback_mail.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../theme/theme_harness.dart';
import '../widgets/fake_feedback_launcher.dart';

/// Church 38 as the bootstrap import leaves it, without a description.
final ChurchDetails _cached = BootstrapImporter.churchFromLegacyRow({
  'tid': 38,
  'nev': 'Belvárosi Nagyboldogasszony-templom',
  'varos': 'Budapest V. kerület',
  'cim': 'Március 15. tér',
  'kep': 'https://miserend.hu/kepek/templomok/38/a.jpg',
});

/// Church 38 as a full API answer leaves it, with [description].
ChurchDetails _withDescription(String description) => ChurchDetails(
  id: 38,
  name: 'Belvárosi Nagyboldogasszony-templom',
  commonName: null,
  names: const [],
  alternativeNames: const [],
  country: null,
  diocese: null,
  county: null,
  city: 'Budapest V. kerület',
  street: 'Március 15. tér',
  gettingThere: null,
  parish: null,
  description: description,
  accessibility: null,
  email: null,
  links: const [],
  languages: const [],
  massScheduleNote: null,
  adorations: const [],
  hasConfession: null,
  communities: const [],
  lat: null,
  lon: null,
  photos: const ['https://miserend.hu/kepek/templomok/38/a.jpg'],
  updatedAt: null,
  localSyncedAt: null,
  isGreek: null,
);

/// Hands out [cached] from the cache and [fresh] once refreshed, and records
/// the day each was asked for.
class _FakeChurchOfTheDay extends ChurchOfTheDayLoader {
  _FakeChurchOfTheDay({this.cached, this.fresh});

  final ChurchDetails? cached;
  final ChurchDetails? fresh;
  final List<DateTime> days = [];

  @override
  Future<ChurchDetails?> loadCached(DateTime today) async {
    days.add(today);
    return cached;
  }

  @override
  Future<ChurchDetails?> refresh(DateTime today) async => fresh ?? cached;
}

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Miserend',
      packageName: 'hu.miserend',
      version: '1.2.3',
      buildNumber: '45',
      buildSignature: '',
    );
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    Size size = const Size(440, 1800),
    FeedbackLauncher? feedback,
    Future<bool> Function(Uri uri)? openLink,
    ChurchOfTheDayLoader? churchOfTheDay,
    Brightness brightness = Brightness.light,
    TargetPlatform platform = TargetPlatform.android,
    double textScale = 1,
  }) async {
    // Tall enough for every card, so none is left unbuilt below the fold.
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: miserendTheme(brightness, platform: platform),
        home: AboutPage(
          feedback: feedback,
          openLink: openLink,
          churchOfTheDay: churchOfTheDay ?? _FakeChurchOfTheDay(),
          clock: () => DateTime(2026, 9, 17, 10, 0),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the Visszajelzés button is no hero: the Térkép tab\'s '
      'button is alive beside it, and two default tags break the next '
      'full-screen page', (tester) async {
    await pumpPage(tester);

    expect(
      tester
          .widget<FloatingActionButton>(find.byType(FloatingActionButton))
          .heroTag,
      isNull,
    );
  });

  testWidgets('shows the version beside the developer', (tester) async {
    await pumpPage(tester);
    expect(find.text('Névjegy'), findsOneWidget);
    expect(find.textContaining('Szent József Hackathon'), findsOneWidget);
    expect(find.text('Verzió: 1.2.3 (45)'), findsOneWidget);
  });

  testWidgets('lists the sections in order, the web version last', (
    tester,
  ) async {
    await pumpPage(
      tester,
      churchOfTheDay: _FakeChurchOfTheDay(cached: _cached),
    );
    final tops =
        [
          find.text('Mai templom ajánlatunk'),
          find.text('Fejlesztő'),
          find.text('Forráskód'),
          find.text('miserend.hu'),
        ].map((finder) => tester.getTopLeft(finder).dy).toList();
    expect(tops, [...tops]..sort());
  });

  testWidgets('has no publisher tile', (tester) async {
    await pumpPage(tester);
    expect(find.text('Kiadó'), findsNothing);
    expect(find.textContaining('Jézus Társasága'), findsNothing);
  });

  testWidgets('the miserend.hu tile opens the web version', (tester) async {
    final opened = <Uri>[];
    await pumpPage(
      tester,
      openLink: (uri) async {
        opened.add(uri);
        return true;
      },
    );
    await tester.tap(find.text('miserend.hu'));
    await tester.pumpAndSettle();
    expect(opened.single, Uri.parse('https://miserend.hu'));
  });

  testWidgets('the source code link opens the repository', (tester) async {
    final opened = <Uri>[];
    await pumpPage(
      tester,
      openLink: (uri) async {
        opened.add(uri);
        return true;
      },
    );
    await tester.tap(find.text('A projekt a GitHubon'));
    await tester.pumpAndSettle();
    expect(
      opened.single,
      Uri.parse('https://github.com/szanatil/Miserend-Flutter'),
    );
  });

  testWidgets('the feedback button floats in view on a small phone', (
    tester,
  ) async {
    await pumpPage(
      tester,
      size: const Size(320, 568),
      churchOfTheDay: _FakeChurchOfTheDay(cached: _cached),
    );
    final button = tester.getRect(
      find.widgetWithText(FloatingActionButton, 'Visszajelzés'),
    );
    expect(button.bottom, lessThanOrEqualTo(568));
    expect(button.top, greaterThan(568 / 2));
  });

  testWidgets('the last tile can scroll clear of the feedback button', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(320, 568));
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    final tile = tester.getRect(find.text('miserend.hu'));
    final button = tester.getRect(
      find.widgetWithText(FloatingActionButton, 'Visszajelzés'),
    );
    expect(tile.bottom, lessThanOrEqualTo(button.top));
  });

  testWidgets('the feedback button opens the feedback mail', (tester) async {
    final feedback = FakeFeedbackLauncher();
    await pumpPage(tester, feedback: feedback);
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Visszajelzés'));
    await tester.pumpAndSettle();
    expect(feedback.launched.single.path, feedbackAddress);
  });

  group('the church of the day', () {
    testWidgets('shows the photo, name and address at once', (tester) async {
      final loader = _FakeChurchOfTheDay(cached: _cached);
      await pumpPage(tester, churchOfTheDay: loader);

      expect(find.text('Mai templom ajánlatunk'), findsOneWidget);
      final photo = tester.widget<FadeInImage>(find.byType(FadeInImage));
      expect(
        (photo.image as ResizeImage).imageProvider,
        isA<NetworkImage>().having(
          (image) => image.url,
          'url',
          'https://miserend.hu/kepek/templomok/38/a.jpg',
        ),
      );
      expect(find.text('Belvárosi Nagyboldogasszony-templom'), findsOneWidget);
      expect(find.text('Budapest V. kerület, Március 15. tér'), findsOneWidget);
      expect(loader.days.single, DateTime(2026, 9, 17, 10, 0));
    });

    testWidgets('adds the description once the API has answered', (
      tester,
    ) async {
      await pumpPage(
        tester,
        churchOfTheDay: _FakeChurchOfTheDay(
          cached: _cached,
          fresh: _withDescription('A templom t&ouml;rt&eacute;nete'),
        ),
      );

      expect(find.text('A templom története'), findsOneWidget);
    });

    testWidgets('a long description wraps whole rather than being cut off '
        '(EL2)', (tester) async {
      final description = List.filled(30, 'A templom története.').join(' ');
      await pumpPage(
        tester,
        churchOfTheDay: _FakeChurchOfTheDay(
          cached: _withDescription(description),
        ),
      );

      final text = tester.widget<Text>(find.text(description));
      expect(text.maxLines, isNull);
      expect(text.overflow, isNot(TextOverflow.ellipsis));
    });

    testWidgets('is left out when the cache has no church', (tester) async {
      await pumpPage(tester, churchOfTheDay: _FakeChurchOfTheDay());

      expect(find.text('Mai templom ajánlatunk'), findsNothing);
      expect(find.text('Fejlesztő'), findsOneWidget);
    });
  });

  for (final brightness in Brightness.values) {
    testWidgets('in $brightness, the page stands on the surface with roles '
        'for its text and links (SZ4, SZ5)', (tester) async {
      await pumpPage(tester, brightness: brightness);
      final scheme = schemeOf(brightness);

      final ground = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(Scaffold),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(ground.color, scheme.surface);
      expect(
        drawnStyle(tester, find.text('Verzió: 1.2.3 (45)')).color,
        scheme.onSurfaceVariant,
      );
      expect(
        drawnStyle(tester, find.text('A projekt a GitHubon')).color,
        scheme.primary,
      );
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets('in $brightness, the source code link is bodyMedium in '
        'primary, like the text around it (TI2, SZ4)', (tester) async {
      await pumpPage(tester, brightness: brightness);
      final link = find.text('A projekt a GitHubon');
      final theme = Theme.of(tester.element(link));

      expect(
        tester.widget<Text>(link).style,
        theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary),
      );
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets('in $brightness, meets the accessibility guidelines '
        '(AM1, AM3, AM5)', (tester) async {
      await pumpPage(
        tester,
        brightness: brightness,
        platform: defaultTargetPlatform,
      );

      await expectAccessibilityGuidelines(tester);
    }, variant: eh4Platforms);
  }

  group('fits (EH3, EH4)', () {
    for (final platform in eh4Platforms.values) {
      for (final brightness in Brightness.values) {
        for (final width in eh4Widths) {
          for (final textScale in eh4TextScales) {
            testWidgets('at $width dp and text scale $textScale on $platform '
                'in $brightness', (tester) async {
              await pumpPage(
                tester,
                size: Size(width, 3000),
                platform: platform,
                brightness: brightness,
                textScale: textScale,
                churchOfTheDay: _FakeChurchOfTheDay(
                  cached: _withDescription('A templom története'),
                ),
              );

              expect(find.text('Mai templom ajánlatunk'), findsOneWidget);
              expect(tester.takeException(), isNull);
            });
          }
        }
      }
    }
  });

  for (final width in const [el3Width, threeColumnWidth]) {
    testWidgets(
      'on a $width dp screen the sections are at most 640 wide, centred, in '
      'one column (EL3)',
      (tester) async {
        await pumpPage(tester, size: Size(width, 1800));

        expectCentredContent(
          tester,
          find.ancestor(
            of: find.text('Fejlesztő'),
            matching: find.byType(Card),
          ),
          screenWidth: width,
        );
      },
    );
  }
}
