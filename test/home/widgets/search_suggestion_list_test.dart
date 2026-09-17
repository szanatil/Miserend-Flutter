import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/home/widgets/search_suggestion_list.dart';

void main() {
  testWidgets(
    'scrolled to the end with the keyboard up, the last suggestion closes '
    'the list',
    (tester) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(1320, 2868);
      addTearDown(tester.view.reset);

      final controller = SearchController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: SearchAnchor.bar(
                isFullScreen: false,
                viewConstraints: const BoxConstraints(maxHeight: 360),
                shrinkWrap: true,
                searchController: controller,
                viewBuilder:
                    (suggestions) =>
                        SearchSuggestionList(suggestions: suggestions),
                suggestionsBuilder:
                    (context, controller) => [
                      for (var i = 0; i < 20; i++)
                        ListTile(title: Text('Templom $i')),
                    ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(SearchBar));
      await tester.pumpAndSettle();
      // The keyboard comes up once the view is open.
      tester.view.viewInsets = const FakeViewPadding(bottom: 1000);
      await tester.pumpAndSettle();

      final list = find.byType(ListView);
      await tester.drag(list, const Offset(0, -5000));
      await tester.pumpAndSettle();

      expect(
        tester.getBottomLeft(find.text('Templom 19')).dy,
        greaterThan(tester.getBottomLeft(list).dy - 56),
      );
    },
  );
}
