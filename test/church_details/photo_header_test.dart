import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/church_details/widgets/photo_header.dart';

const List<String> _two = [
  'https://miserend.hu/kepek/templomok/38/a.jpg',
  'https://miserend.hu/kepek/templomok/38/b.jpg',
];

Widget _host(List<String> photos) {
  return MaterialApp(
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
}
