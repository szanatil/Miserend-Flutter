import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/home/advanced_search/widgets/result_counter.dart';
import 'package:miserend/theme/miserend_theme.dart';

Widget _host({bool disableAnimations = false}) {
  final controller = ScrollController();
  return MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: MaterialApp(
      theme: miserendTheme(Brightness.light),
      home: Scaffold(
        body: Stack(
          children: [
            ListView(
              controller: controller,
              children: [for (var i = 0; i < 40; i++) Text('$i')],
            ),
            ResultCounter(
              controller: controller,
              list: GlobalKey(),
              columns: 1,
              shown: 8,
              found: 42,
              foundIsFinal: true,
            ),
          ],
        ),
      ),
    ),
  );
}

AnimatedOpacity _fade(WidgetTester tester) =>
    tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));

void main() {
  testWidgets('the counter fades out in Durations.medium1, accelerating '
      '(KO20, MO2)', (tester) async {
    await tester.pumpWidget(_host());

    expect(_fade(tester).duration, Durations.medium1);
    expect(_fade(tester).curve, Easing.emphasizedAccelerate);
  });

  testWidgets('the counter comes in decelerating (MO2)', (tester) async {
    await tester.pumpWidget(_host());

    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pump();

    expect(_fade(tester).opacity, 1);
    expect(_fade(tester).duration, Durations.medium1);
    expect(_fade(tester).curve, Easing.emphasizedDecelerate);

    // Let the linger timer run out.
    await tester.pumpAndSettle(ResultCounter.lingerFor);
  });

  testWidgets('with reduced motion the fade takes at most Durations.short3 '
      '(MO3)', (tester) async {
    await tester.pumpWidget(_host(disableAnimations: true));

    expect(_fade(tester).duration, lessThanOrEqualTo(Durations.short3));
  });
}
