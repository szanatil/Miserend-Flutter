import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/colors.dart';
import 'package:miserend/home/widgets/section_bar.dart';

void main() {
  Future<void> pumpBar(WidgetTester tester, SectionBar bar) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSwatch(
            primarySwatch: CustomColors.purple,
          ),
        ),
        home: DefaultTabController(
          length: 2,
          child: Scaffold(appBar: bar, body: const SizedBox.shrink()),
        ),
      ),
    );
  }

  Color? colorOf(WidgetTester tester) =>
      tester
          .widget<Material>(
            find
                .descendant(
                  of: find.byType(SectionBar),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color;

  testWidgets('a title bar says its title in white', (tester) async {
    await pumpBar(tester, const SectionBar.title('Mai misék'));

    expect(find.text('Mai misék'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Mai misék')).style?.color,
      Colors.white,
    );
  });

  testWidgets('a title bar is as tall and as purple as a tab bar', (
    tester,
  ) async {
    await pumpBar(
      tester,
      const SectionBar.tabs([Tab(text: 'Közeli'), Tab(text: 'Kedvencek')]),
    );
    final tabsHeight = tester.getSize(find.byType(SectionBar)).height;
    final tabsColor = colorOf(tester);
    expect(find.text('Közeli'), findsOneWidget);

    await pumpBar(tester, const SectionBar.title('Mai misék'));

    expect(tester.getSize(find.byType(SectionBar)).height, tabsHeight);
    expect(colorOf(tester), tabsColor);
    expect(tabsColor?.toARGB32(), CustomColors.purple.toARGB32());
  });
}
