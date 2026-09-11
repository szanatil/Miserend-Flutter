import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/church_details/widgets/expandable_info_tile.dart';

const String _long =
    'Egy nagyon hosszú leírás, amely bőven túlnyúlik három soron, hogy a '
    'csempe kénytelen legyen összecsukni. Ismétlés a hosszért: egy nagyon '
    'hosszú leírás, amely bőven túlnyúlik három soron. És még egyszer, hogy '
    'biztosan ne férjen el a megadott szélességen belül sem.';

Widget _host(String text) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(width: 200, child: ExpandableInfoTile(text: text)),
    ),
  );
}

void main() {
  testWidgets('a short text gets no control at all', (tester) async {
    await tester.pumpWidget(_host('Rövid.'));

    expect(find.text('Több'), findsNothing);
    expect(find.text('Kevesebb'), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
  });

  testWidgets('collapsed shows a down arrow and "Több"', (tester) async {
    await tester.pumpWidget(_host(_long));

    expect(find.text('Több'), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    // The old wording is gone.
    expect(find.text('Tovább'), findsNothing);
  });

  testWidgets('expanded flips to an up arrow and "Kevesebb"', (tester) async {
    await tester.pumpWidget(_host(_long));

    await tester.tap(find.text('Több'));
    await tester.pump();

    expect(find.text('Kevesebb'), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
  });

  testWidgets('collapses again on a second tap', (tester) async {
    await tester.pumpWidget(_host(_long));

    await tester.tap(find.text('Több'));
    await tester.pump();
    await tester.tap(find.text('Kevesebb'));
    await tester.pump();

    expect(find.text('Több'), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
  });
}
