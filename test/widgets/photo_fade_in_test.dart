import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/widgets/photo_fade_in.dart';

Widget _host({bool disableAnimations = false}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: const Directionality(
      textDirection: TextDirection.ltr,
      child: PhotoFadeIn(
        image: 'https://miserend.hu/kepek/templomok/38/a.jpg',
        placeholder: 'assets/images/church_blurred.png',
        // The photo never loads in a test.
        imageErrorBuilder: _blank,
      ),
    ),
  );
}

Widget _blank(BuildContext context, Object error, StackTrace? stackTrace) =>
    const SizedBox();

void main() {
  testWidgets('the photo fades in over the placeholder in Durations.medium1 '
      '(MO1, MO2)', (tester) async {
    await tester.pumpWidget(_host());

    final image = tester.widget<FadeInImage>(find.byType(FadeInImage));
    expect(image.fadeInDuration, Durations.medium1);
    expect(image.fadeInCurve, Easing.emphasizedDecelerate);
    expect(image.fadeOutDuration, Durations.short3);
    expect(image.fadeOutCurve, Easing.emphasizedAccelerate);
  });

  testWidgets('with reduced motion the photo replaces the placeholder at once '
      '(MO3)', (tester) async {
    await tester.pumpWidget(_host(disableAnimations: true));

    expect(find.byType(FadeInImage), findsNothing);
    // Until the photo arrives, the placeholder stands in its place.
    expect(
      find.image(const AssetImage('assets/images/church_blurred.png')),
      findsOneWidget,
    );
  });
}
