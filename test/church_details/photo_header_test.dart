import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/church_details/widgets/photo_header.dart';
import 'package:miserend/theme/miserend_theme.dart';

import '../theme/theme_harness.dart';

const List<String> _two = [
  'https://miserend.hu/kepek/templomok/38/a.jpg',
  'https://miserend.hu/kepek/templomok/38/b.jpg',
];

Widget _host(List<String> photos, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: miserendTheme(brightness),
    home: Scaffold(
      body: SizedBox(
        height: 200,
        child: ChurchPhotoHeader(
          photos: photos,
          height: 200,
          heroPrefix: 'church-38-photo',
        ),
      ),
    ),
  );
}

DecoratedBox _scrimOf(WidgetTester tester, Finder indicator) =>
    tester.widget<DecoratedBox>(
      find.ancestor(of: indicator, matching: find.byType(DecoratedBox)).first,
    );

/// Which page the slideshow is on, read off the controller rather than the
/// pixels, since the photos themselves never load in a test.
double _page(WidgetTester tester) {
  final view = tester.widget<PageView>(find.byType(PageView));
  return view.controller!.page ?? 0;
}

void main() {
  testWidgets('a church with no photo gets the placeholder, not a slideshow', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const []));

    expect(find.byType(PageView), findsNothing);
    expect(find.byType(Image), findsWidgets);
  });

  testWidgets('a single photo does not become a slideshow', (tester) async {
    await tester.pumpWidget(_host(const ['https://miserend.hu/a.jpg']));

    expect(find.byType(PageView), findsNothing);
  });

  testWidgets('two photos advance on their own', (tester) async {
    await tester.pumpWidget(_host(_two));
    expect(_page(tester), 0);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(_page(tester), 1);
  });

  testWidgets('a slide is over within Durations.medium3 (KO19)', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_two));

    // The timer fires at 4 s, and the slide takes its first frame there.
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(Durations.medium3 - const Duration(milliseconds: 10));
    expect(_page(tester), lessThan(1));
    await tester.pump(const Duration(milliseconds: 10));

    expect(_page(tester), 1);
  });

  testWidgets('with reduced motion the slideshow never starts (MO3, KO19)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _host(_two),
      ),
    );

    await tester.pump(const Duration(seconds: 20));
    await tester.pumpAndSettle();

    expect(_page(tester), 0);
  });

  testWidgets('a swipe stops the slideshow for good', (tester) async {
    await tester.pumpWidget(_host(_two));

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(_page(tester), 1);

    // Well past several intervals: it must not keep moving on its own.
    await tester.pump(const Duration(seconds: 20));
    await tester.pumpAndSettle();

    expect(_page(tester), 1);
  });

  testWidgets('the slideshow starts when the photos arrive after the first '
      'build', (tester) async {
    // The cache read lands after the page is already on screen, so the header
    // is first built with nothing.
    await tester.pumpWidget(_host(const []));
    await tester.pumpWidget(_host(_two));

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(_page(tester), 1);
  });

  for (final brightness in Brightness.values) {
    testWidgets('the page indicator reads over the photo in $brightness '
        '(KO19)', (tester) async {
      await tester.pumpWidget(_host(_two, brightness: brightness));
      final colors = miserendColorsOf(brightness);

      final indicator = find.byKey(ChurchPhotoHeader.pageIndicatorKey);
      final scrim =
          tester
                  .widget<DecoratedBox>(
                    find
                        .ancestor(
                          of: indicator,
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(scrim.gradient!.colors.last, colors.photoScrim);
      // Full strength from the top of the dots down, not still fading in
      // behind them.
      final gradient = scrim.gradient!;
      final dotsTop =
          tester.getTopLeft(indicator).dy -
          tester.getTopLeft(find.byWidget(_scrimOf(tester, indicator))).dy;
      final height =
          tester.getSize(find.byWidget(_scrimOf(tester, indicator))).height;
      expect(gradient.stops!.last, lessThanOrEqualTo(dotsTop / height));

      final dots =
          tester
              .widgetList<Container>(
                find.descendant(
                  of: indicator,
                  matching: find.byType(Container),
                ),
              )
              .map((dot) => dot.decoration! as BoxDecoration)
              .toList();
      expect(dots, hasLength(2));
      // The current photo's dot is filled, the other only a ring: told
      // apart by shape, not by a fainter white.
      expect(dots[0].color, colors.onPhoto);
      expect(dots[1].color, isNull);
      expect(dots[1].border, Border.all(color: colors.onPhoto, width: 1.5));
    });
  }

  for (final brightness in Brightness.values) {
    for (final photos in [const <String>[], _two.sublist(0, 1), _two]) {
      testWidgets('with ${photos.length} photo(s) in $brightness, the status '
          'bar stands on the full scrim, which fades out below the toolbar '
          '(KO19)', (tester) async {
        const statusBar = 47.0;
        await tester.pumpWidget(
          MaterialApp(
            theme: miserendTheme(brightness),
            home: MediaQuery(
              data: const MediaQueryData(
                padding: EdgeInsets.only(top: statusBar),
              ),
              child: Scaffold(
                body: SizedBox(
                  height: 300,
                  child: ChurchPhotoHeader(
                    photos: photos,
                    height: 300,
                    heroPrefix: 'church-38-photo',
                  ),
                ),
              ),
            ),
          ),
        );
        final colors = miserendColorsOf(brightness);

        final scrim = find.byKey(ChurchPhotoHeader.topScrimKey);
        final height = tester.getSize(scrim).height;
        expect(height, statusBar + kToolbarHeight);
        final gradient =
            (tester.widget<DecoratedBox>(scrim).decoration as BoxDecoration)
                .gradient!;
        expect(gradient.colors, [
          colors.photoScrim,
          colors.photoScrim,
          Colors.transparent,
        ]);
        expect(gradient.stops, [0, statusBar / height, 1]);
      });
    }
  }
}
