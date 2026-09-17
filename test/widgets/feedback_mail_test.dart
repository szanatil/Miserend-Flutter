import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/widgets/feedback_mail.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  group('the feedback mail', () {
    final uri = feedbackMailUri(
      version: '1.0.0',
      buildNumber: '7',
      operatingSystem: 'android',
      operatingSystemVersion: '14',
    );

    test('goes to the hackathon team with the subject', () {
      expect(uri.scheme, 'mailto');
      expect(uri.path, 'szentjozsefhackathon@jezsuita.hu');
      expect(
        uri.toString(),
        contains('subject=Miserend%20app%20%E2%80%93%20visszajelz%C3%A9s'),
      );
    });

    test('encodes spaces as %20, never as +', () {
      final query = uri.toString().split('?').last;
      expect(query, isNot(contains('+')));
      expect(query, contains('%20'));
    });

    test('leaves room above the version, build number and platform', () {
      final body = Uri.decodeComponent(
        RegExp(r'body=([^&]*)').firstMatch(uri.toString())!.group(1)!,
      );
      expect(body, '\n\n---\nMiserend app 1.0.0 (7)\nandroid 14');
    });
  });

  group('sending feedback', () {
    setUp(() {
      PackageInfo.setMockInitialValues(
        appName: 'Miserend',
        packageName: 'hu.miserend',
        version: '1.0.0',
        buildNumber: '7',
        buildSignature: '',
      );
    });

    Future<void> tapSend(WidgetTester tester, FeedbackLauncher launcher) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder:
                  (context) => TextButton(
                    onPressed: () => launcher.send(context),
                    child: const Text('Küldés'),
                  ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Küldés'));
      await tester.pumpAndSettle();
    }

    const noMailApp =
        'Nincs levelezőprogram a telefonon. '
        'Írj nekünk: szentjozsefhackathon@jezsuita.hu';

    testWidgets('hands the mail to the mail app', (tester) async {
      final launched = <Uri>[];
      await tapSend(
        tester,
        FeedbackLauncher(
          launch: (uri) async {
            launched.add(uri);
            return true;
          },
        ),
      );
      expect(launched.single.path, 'szentjozsefhackathon@jezsuita.hu');
      expect(launched.single.toString(), contains('1.0.0%20(7)'));
      expect(find.text(noMailApp), findsNothing);
    });

    testWidgets('with no mail app it gives the address instead', (
      tester,
    ) async {
      await tapSend(tester, FeedbackLauncher(launch: (_) async => false));
      expect(find.text(noMailApp), findsOneWidget);
    });

    testWidgets('a launch that throws gives the address too', (tester) async {
      await tapSend(
        tester,
        FeedbackLauncher(launch: (_) async => throw Exception('no activity')),
      );
      expect(find.text(noMailApp), findsOneWidget);
    });
  });
}
