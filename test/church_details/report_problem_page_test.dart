import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/api/api_result.dart';
import 'package:miserend/api/problem_type.dart';
import 'package:miserend/church_details/problem_report_sender.dart';
import 'package:miserend/church_details/report_problem_page.dart';
import 'package:miserend/theme/adaptive.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One report as the page handed it over.
typedef _Sent =
    ({
      int churchId,
      ProblemType type,
      String text,
      String? email,
      DateTime dataAsOf,
    });

/// Records every send and answers each with [answer], or, while [pending] is
/// set, waits for it.
class _FakeSender extends ProblemReportSender {
  _FakeSender({this.answer = const ApiSuccess<void>(null)});

  ApiResult<void> answer;
  Completer<ApiResult<void>>? pending;
  final List<_Sent> sent = [];

  @override
  Future<ApiResult<void>> send({
    required int churchId,
    required ProblemType type,
    required String text,
    String? email,
    required DateTime dataAsOf,
  }) async {
    sent.add((
      churchId: churchId,
      type: type,
      text: text,
      email: email,
      dataAsOf: dataAsOf,
    ));
    return pending?.future ?? answer;
  }
}

final TargetPlatformVariant _bothPlatforms = TargetPlatformVariant(const {
  TargetPlatform.android,
  TargetPlatform.iOS,
});

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// The page, opened as the details page opens it, from a plain screen so
  /// that closing it can be seen.
  Future<void> openPage(
    WidgetTester tester,
    _FakeSender sender, {
    // Tall enough for the whole form, so an error text is found whether or
    // not the list has scrolled to it.
    Size size = const Size(440, 1400),
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed:
                      () => pushMiserendTaskFlow<void>(
                        context,
                        (_) => ReportProblemPage(
                          churchId: 38,
                          churchName: 'Belvárosi Nagyboldogasszony-templom',
                          dataAsOf: DateTime(2026, 9, 3, 17, 45),
                          sender: sender,
                        ),
                      ),
                  child: const Text('Megnyitás'),
                ),
              ),
        ),
      ),
    );
    await tester.tap(find.text('Megnyitás'));
    await tester.pumpAndSettle();
  }

  Future<void> fill(
    WidgetTester tester, {
    String? type,
    String? text,
    String? email,
  }) async {
    if (type != null) await tester.tap(find.text(type));
    if (text != null) {
      await tester.enterText(find.byKey(ReportProblemPage.textKey), text);
    }
    if (email != null) {
      await tester.enterText(find.byKey(ReportProblemPage.emailKey), email);
    }
    await tester.pump();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Küldés'));
    await tester.tap(find.text('Küldés'));
    await tester.pump();
  }

  bool selected(WidgetTester tester, ProblemType type) =>
      tester
          .widget<RadioGroup<ProblemType>>(find.byType(RadioGroup<ProblemType>))
          .groupValue ==
      type;

  testWidgets('shows the church name, with no type chosen', (tester) async {
    await openPage(tester, _FakeSender());

    expect(find.text('Hibajelentés'), findsOneWidget);
    expect(find.text('Belvárosi Nagyboldogasszony-templom'), findsOneWidget);
    expect(find.text('Rossz pozíció'), findsOneWidget);
    expect(find.text('Rossz miseidőpont'), findsOneWidget);
    expect(find.text('Egyéb'), findsOneWidget);
    for (final type in ProblemType.values) {
      expect(selected(tester, type), isFalse);
    }
  });

  testWidgets('an empty form shows every error and sends nothing', (
    tester,
  ) async {
    final sender = _FakeSender();
    await openPage(tester, sender);

    await fill(tester, email: 'nem-cim');
    await submit(tester);

    expect(find.text('Válaszd ki, milyen hibát jelentesz.'), findsOneWidget);
    expect(find.text('Írd le, mi a hiba.'), findsOneWidget);
    expect(find.text('Ez nem e-mail cím.'), findsOneWidget);
    expect(sender.sent, isEmpty);
  });

  testWidgets('a wrong mass time needs a description too', (tester) async {
    final sender = _FakeSender();
    await openPage(tester, sender);

    await fill(tester, type: 'Rossz miseidőpont', text: '   ');
    await submit(tester);

    expect(find.text('Írd le, mi a hiba.'), findsOneWidget);
    expect(find.text('Válaszd ki, milyen hibát jelentesz.'), findsNothing);
    expect(sender.sent, isEmpty);
  });

  testWidgets('a malformed email is an error, an empty one is not', (
    tester,
  ) async {
    final sender = _FakeSender(answer: const ApiFailed(ApiFailure.serverError));
    await openPage(tester, sender);

    await fill(
      tester,
      type: 'Egyéb',
      text: 'Megszűnt a templom.',
      email: 'anna@',
    );
    await submit(tester);
    expect(find.text('Ez nem e-mail cím.'), findsOneWidget);
    expect(sender.sent, isEmpty);

    await fill(tester, email: '');
    await submit(tester);
    expect(find.text('Ez nem e-mail cím.'), findsNothing);
    expect(sender.sent, hasLength(1));
    expect(sender.sent.single.email, isNull);
  });

  testWidgets('sends the church, the choice and the day of the data', (
    tester,
  ) async {
    final sender = _FakeSender();
    await openPage(tester, sender);

    await fill(
      tester,
      type: 'Rossz pozíció',
      text: 'A templom a tér másik oldalán áll.',
      email: 'anna@example.com',
    );
    await submit(tester);

    final report = sender.sent.single;
    expect(report.churchId, 38);
    expect(report.type, ProblemType.wrongPosition);
    expect(report.text, 'A templom a tér másik oldalán áll.');
    expect(report.email, 'anna@example.com');
    expect(report.dataAsOf, DateTime(2026, 9, 3, 17, 45));
  });

  testWidgets('while sending, a spinner shows and a second tap sends nothing', (
    tester,
  ) async {
    final sender = _FakeSender()..pending = Completer();
    await openPage(tester, sender);
    await fill(tester, type: 'Egyéb', text: 'Megszűnt a templom.');

    await submit(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(
      find.ancestor(
        of: find.byType(CircularProgressIndicator),
        matching: find.byType(FilledButton),
      ),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(sender.sent, hasLength(1));

    sender.pending!.complete(const ApiSuccess<void>(null));
    await tester.pumpAndSettle();
  });

  testWidgets('a sent report closes the page and says so', (tester) async {
    await openPage(tester, _FakeSender());
    await fill(tester, type: 'Egyéb', text: 'Megszűnt a templom.');

    await submit(tester);
    await tester.pumpAndSettle();

    expect(find.byType(ReportProblemPage), findsNothing);
    expect(find.text('Hibajelentés elküldve'), findsOneWidget);
  });

  testWidgets('no connection keeps the page and the text, and says why', (
    tester,
  ) async {
    await openPage(
      tester,
      _FakeSender(answer: const ApiFailed(ApiFailure.noConnection)),
    );
    await fill(tester, type: 'Egyéb', text: 'Megszűnt a templom.');

    await submit(tester);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Nincs kapcsolat, a hibajelentés nem ment el. '
        'Próbáld újra, ha lesz térerő.',
      ),
      findsOneWidget,
    );
    expect(find.byType(ReportProblemPage), findsOneWidget);
    expect(find.text('Megszűnt a templom.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a server error keeps the text and blames miserend.hu', (
    tester,
  ) async {
    await openPage(
      tester,
      _FakeSender(answer: const ApiFailed(ApiFailure.serverError)),
    );
    await fill(tester, type: 'Egyéb', text: 'Megszűnt a templom.');

    await submit(tester);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'A miserend.hu most nem fogadta a hibajelentést. '
        'Próbáld újra később.',
      ),
      findsOneWidget,
    );
    expect(find.byType(ReportProblemPage), findsOneWidget);
    expect(find.text('Megszűnt a templom.'), findsOneWidget);
  });

  testWidgets('the email of a sent report is filled in the next time', (
    tester,
  ) async {
    await openPage(tester, _FakeSender());
    await fill(
      tester,
      type: 'Egyéb',
      text: 'Megszűnt a templom.',
      email: 'anna@example.com',
    );
    await submit(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Megnyitás'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(ReportProblemPage.emailKey),
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text,
      'anna@example.com',
    );
  });

  testWidgets('a report sent with the email cleared forgets it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      ReportProblemPage.emailPreferenceKey: 'anna@example.com',
    });
    await openPage(tester, _FakeSender());
    expect(find.text('anna@example.com'), findsOneWidget);

    await fill(tester, type: 'Egyéb', text: 'Megszűnt a templom.', email: '');
    await submit(tester);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ReportProblemPage.emailPreferenceKey), '');
  });

  testWidgets('a failed report does not remember the email', (tester) async {
    await openPage(
      tester,
      _FakeSender(answer: const ApiFailed(ApiFailure.noConnection)),
    );
    await fill(
      tester,
      type: 'Egyéb',
      text: 'Megszűnt a templom.',
      email: 'anna@example.com',
    );
    await submit(tester);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ReportProblemPage.emailPreferenceKey), isNull);
  });
  testWidgets('Mégse closes the page without sending', (tester) async {
    final sender = _FakeSender();
    await openPage(tester, sender);

    await tester.tap(find.text('Mégse'));
    await tester.pumpAndSettle();

    expect(find.byType(ReportProblemPage), findsNothing);
    expect(sender.sent, isEmpty);
  }, variant: _bothPlatforms);

  group('fits without overflow (EH4)', () {
    for (final width in [320.0, 430.0]) {
      for (final textScale in [1.0, 2.0]) {
        testWidgets('at $width dp and text scale $textScale', (tester) async {
          await openPage(
            tester,
            _FakeSender(),
            size: Size(width, 2400),
            textScale: textScale,
          );

          expect(find.text('Mégse'), findsOneWidget);
          expect(find.text('Küldés'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }, variant: _bothPlatforms);
      }
    }
  });
}
