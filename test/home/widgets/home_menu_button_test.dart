import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/home/widgets/home_menu_button.dart';
import 'package:miserend/widgets/feedback_mail.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../widgets/fake_feedback_launcher.dart';

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Miserend',
      packageName: 'hu.miserend',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  /// The button in an AppBar, as home.dart places it; HomeScreen itself
  /// reaches for the real database and API in its tabs.
  Future<void> openMenu(
    WidgetTester tester, {
    FeedbackLauncher? feedback,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(actions: [HomeMenuButton(feedback: feedback)]),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Menü'));
    await tester.pumpAndSettle();
  }

  testWidgets('the menu offers feedback and the about page', (tester) async {
    await openMenu(tester);
    expect(find.text('Visszajelzés'), findsOneWidget);
    expect(find.text('Az appról'), findsOneWidget);
  });

  testWidgets('the about item opens the about page', (tester) async {
    await openMenu(tester);
    await tester.tap(find.text('Az appról'));
    await tester.pumpAndSettle();
    expect(find.text('Készítette: Szent József Hackathon'), findsOneWidget);
  });

  testWidgets('the feedback item opens the feedback mail', (tester) async {
    final feedback = FakeFeedbackLauncher();
    await openMenu(tester, feedback: feedback);
    await tester.tap(find.text('Visszajelzés'));
    await tester.pumpAndSettle();
    expect(feedback.launched.single.path, feedbackAddress);
  });
}
