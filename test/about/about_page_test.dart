import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/about/about_page.dart';
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
  }) async {
    await tester.pumpWidget(MaterialApp(home: AboutPage(feedback: feedback)));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the version, the data source and the makers', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(find.text('Az appról'), findsOneWidget);
    expect(find.text('Miserend'), findsOneWidget);
    expect(find.text('Verzió: 1.2.3 (45)'), findsOneWidget);
    expect(
      find.textContaining('Az adatokat a miserend.hu szolgáltatja.'),
      findsOneWidget,
    );
    expect(find.text('Készítette: Szent József Hackathon'), findsOneWidget);
  });

  testWidgets('the feedback button opens the feedback mail', (tester) async {
    final feedback = FakeFeedbackLauncher();
    await pumpPage(tester, feedback: feedback);
    await tester.tap(find.text('Visszajelzés küldése'));
    await tester.pumpAndSettle();
    expect(feedback.launched.single.path, feedbackAddress);
  });

  testWidgets('the licenses button opens the license page', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.text('Nyílt forrású licencek'));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });
}
