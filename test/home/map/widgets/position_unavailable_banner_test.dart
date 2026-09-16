import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/home/map/widgets/position_unavailable_banner.dart';
import 'package:miserend/location_provider.dart';

import '../../../fake_location_provider.dart';

void main() {
  late FakeLocationProvider location;
  late int retries;
  late int sentToSettings;
  late int closes;

  setUp(() {
    location = FakeLocationProvider();
    retries = 0;
    sentToSettings = 0;
    closes = 0;
  });

  Future<void> pumpBanner(
    WidgetTester tester,
    PositionUnavailableReason reason,
  ) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PositionUnavailableBanner(
            reason: reason,
            location: location,
            onRetry: () => retries++,
            onSentToSettings: () => sentToSettings++,
            onClose: () => closes++,
          ),
        ),
      ),
    );
  }

  group('the way out of each reason', () {
    testWidgets('a denied permission is asked for again, in the app', (
      tester,
    ) async {
      await pumpBanner(tester, PositionUnavailableReason.permissionDenied);

      expect(
        find.text('A helyzeted mutatásához engedélyezd a helyadatot.'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Engedélyezés'));

      expect(retries, 1);
      expect(
        sentToSettings,
        0,
        reason: 'the prompt is in the app, so there is no coming back to',
      );
    });

    testWidgets('a permission denied for good opens the app settings', (
      tester,
    ) async {
      await pumpBanner(
        tester,
        PositionUnavailableReason.permissionDeniedForever,
      );

      expect(
        find.text(
          'A helyzeted mutatásához engedélyezd a helyadatot a telefon '
          'beállításaiban.',
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.widgetWithText(TextButton, 'Beállítások megnyitása'),
      );

      expect(location.appSettingsOpened, 1);
      expect(sentToSettings, 1);
      expect(retries, 0);
    });

    testWidgets('a disabled location service opens the location settings', (
      tester,
    ) async {
      await pumpBanner(tester, PositionUnavailableReason.serviceDisabled);

      expect(
        find.text('A helyzeted mutatásához kapcsold be a helymeghatározást.'),
        findsOneWidget,
      );
      await tester.tap(
        find.widgetWithText(TextButton, 'Beállítások megnyitása'),
      );

      expect(location.locationSettingsOpened, 1);
      expect(sentToSettings, 1);
    });

    testWidgets('no fix in time has nothing to press', (tester) async {
      await pumpBanner(tester, PositionUnavailableReason.noFreshFix);

      expect(
        find.text('Nem sikerült meghatározni a helyzetedet.'),
        findsOneWidget,
      );
      expect(find.byType(TextButton), findsNothing);
    });
  });

  testWidgets('the close button says so without settling anything', (
    tester,
  ) async {
    await pumpBanner(tester, PositionUnavailableReason.serviceDisabled);

    await tester.tap(find.byTooltip('Bezárás'));

    expect(closes, 1);
    expect(location.locationSettingsOpened, 0);
    expect(retries, 0);
  });
}
