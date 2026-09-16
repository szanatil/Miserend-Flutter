import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/widgets/stale_data_retry.dart';

void main() {
  late int retries;

  setUp(() => retries = 0);

  Future<void> pumpRetry(
    WidgetTester tester, {
    required Future<void> Function() onRetry,
    bool present = true,
  }) => tester.pumpWidget(
    MaterialApp(
      home:
          present
              ? StaleDataRetry(
                onRetry: onRetry,
                child: const Text('Nincs kapcsolat'),
              )
              : const SizedBox.shrink(),
    ),
  );

  testWidgets('asks again on every turn of the clock while it is on screen', (
    tester,
  ) async {
    await pumpRetry(tester, onRetry: () async => retries++);
    expect(retries, 0, reason: 'the screen has just fetched');

    await tester.pump(StaleDataRetry.retryEvery);
    expect(retries, 1);

    await tester.pump(StaleDataRetry.retryEvery);
    await tester.pump(StaleDataRetry.retryEvery);
    expect(retries, 3, reason: 'it does not give up after a few tries');
  });

  testWidgets('asks again the moment the app comes back, without waiting out '
      'the clock', (tester) async {
    await pumpRetry(tester, onRetry: () async => retries++);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(retries, 1);
  });

  testWidgets('does not start a second call on top of a slow one', (
    tester,
  ) async {
    final slow = Completer<void>();
    await pumpRetry(
      tester,
      onRetry: () {
        retries++;
        return slow.future;
      },
    );

    await tester.pump(StaleDataRetry.retryEvery);
    await tester.pump(StaleDataRetry.retryEvery);
    await tester.pump(StaleDataRetry.retryEvery);
    expect(retries, 1, reason: 'the first call has not answered yet');

    slow.complete();
    await tester.pump();
    await tester.pump(StaleDataRetry.retryEvery);
    expect(retries, 2);
  });

  testWidgets('stops asking once the screen takes it away', (tester) async {
    await pumpRetry(tester, onRetry: () async => retries++);
    await tester.pump(StaleDataRetry.retryEvery);
    expect(retries, 1);

    // What a successful answer does: the mark, and with it the retry, is gone.
    await pumpRetry(tester, onRetry: () async => retries++, present: false);
    await tester.pump(StaleDataRetry.retryEvery);
    await tester.pump(StaleDataRetry.retryEvery);

    expect(retries, 1);
  });
}
