import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/location_provider.dart';
import 'package:miserend/theme/tokens.dart';
import 'package:miserend/widgets/list_status_view.dart';
import 'package:miserend/widgets/position_unavailable_view.dart';

import '../fake_location_provider.dart';
import '../theme/theme_harness.dart';

/// The status views (DESIGN.md KO8): their elements stand `Spacing.l` apart,
/// and they fit a narrow screen at a large text size (EH4).
void main() {
  Future<void> pumpView(
    WidgetTester tester,
    Widget view, {
    double width = 400,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: view)));
  }

  final views = <String, Widget Function()>{
    'loading': () => const LoadingView(message: 'Templomok betöltése…'),
    'message': () => const MessageView(message: 'Nincs kedvenc templomod.'),
    'position unavailable':
        () => PositionUnavailableView(
          reason: PositionUnavailableReason.permissionDeniedForever,
          purpose: 'A közeli templomokhoz',
          location: FakeLocationProvider(),
          onRetry: () {},
        ),
  };

  testWidgets('the loading spinner and its caption stand Spacing.l apart '
      '(KO8)', (tester) async {
    await pumpView(tester, views['loading']!());

    final spinner = tester.getRect(find.byType(CircularProgressIndicator));
    final caption = tester.getRect(find.text('Templomok betöltése…'));
    expect(caption.top - spinner.bottom, Spacing.l);
  });

  testWidgets('the message and its button stand Spacing.l apart (KO8)', (
    tester,
  ) async {
    await pumpView(tester, views['position unavailable']!());

    final message = tester.getRect(
      find.textContaining('engedélyezd a helyadatot'),
    );
    final button = tester.getRect(find.byType(FilledButton));
    expect(button.top - message.bottom, Spacing.l);
  });

  group('fits (EH4)', () {
    for (final MapEntry(key: name, value: view) in views.entries) {
      for (final width in eh4Widths) {
        for (final textScale in eh4TextScales) {
          testWidgets('$name at $width dp and text scale $textScale', (
            tester,
          ) async {
            await pumpView(tester, view(), width: width, textScale: textScale);

            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });

  testWidgets(
    'the loading spinner is the platform\'s own (KO8, PL2)',
    (tester) async {
      await pumpView(tester, views['loading']!());

      expect(
        find.byType(CupertinoActivityIndicator),
        defaultTargetPlatform == TargetPlatform.iOS
            ? findsOneWidget
            : findsNothing,
      );
    },
    variant: TargetPlatformVariant(const {
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );
}
