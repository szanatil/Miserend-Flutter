import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/menu/menu_page.dart';
import 'package:miserend/widgets/feedback_mail.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../widgets/fake_feedback_launcher.dart';

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
    FeedbackLauncher? feedback,
    Future<bool> Function(Uri uri)? openLink,
  }) async {
    await tester.pumpWidget(
      MaterialApp(home: MenuPage(feedback: feedback, openLink: openLink)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the version on its own tile', (tester) async {
    await pumpPage(tester);
    expect(find.text('Menü'), findsOneWidget);
    expect(find.text('Verzió'), findsOneWidget);
    expect(find.text('1.2.3 (45)'), findsOneWidget);
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

  testWidgets('the feedback button opens the feedback mail', (tester) async {
    final feedback = FakeFeedbackLauncher();
    await pumpPage(tester, feedback: feedback);
    await tester.tap(find.widgetWithText(FilledButton, 'Visszajelzés'));
    await tester.pumpAndSettle();
    expect(feedback.launched.single.path, feedbackAddress);
  });
}
