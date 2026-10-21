import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/api/api_result.dart';
import 'package:miserend/widgets/offline_notice.dart';

import '../theme/theme_harness.dart';

void main() {
  Future<void> pumpBanner(
    WidgetTester tester,
    ApiFailure failure,
    Brightness brightness,
  ) async {
    await pumpThemed(
      tester,
      OfflineBanner(failure: failure, asOf: null, onRetry: () async {}),
      brightness: brightness,
    );
  }

  Color background(WidgetTester tester) =>
      tester
          .widget<Material>(
            find
                .descendant(
                  of: find.byType(OfflineBanner),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color!;

  Color iconColor(WidgetTester tester, ApiFailure failure) =>
      tester.widget<Icon>(find.byIcon(failure.icon)).color!;

  for (final brightness in Brightness.values) {
    group('in $brightness (KO7, SZ4)', () {
      testWidgets('no connection is a quiet grey strip', (tester) async {
        await pumpBanner(tester, ApiFailure.noConnection, brightness);
        final scheme = schemeOf(brightness);

        expect(background(tester), scheme.surfaceContainerHighest);
        expect(
          iconColor(tester, ApiFailure.noConnection),
          scheme.onSurfaceVariant,
        );
        expect(
          drawnStyle(tester, find.text('Nincs kapcsolat, tárolt adatok')).color,
          scheme.onSurfaceVariant,
        );
      });

      testWidgets('a server error stands out in its own container', (
        tester,
      ) async {
        await pumpBanner(tester, ApiFailure.serverError, brightness);
        final colors = miserendColorsOf(brightness);

        expect(background(tester), colors.serverErrorContainer);
        expect(
          iconColor(tester, ApiFailure.serverError),
          colors.serverErrorIcon,
        );
        expect(
          drawnStyle(
            tester,
            find.text('A miserend.hu nem elérhető, tárolt adatok'),
          ).color,
          colors.onServerErrorContainer,
        );
      });
    });
  }

  for (final failure in ApiFailure.values) {
    test('the ${failure.name} explanation dates the data with a closing dot '
        '(FM2)', () {
      expect(
        OfflineNotice.explanation(failure, DateTime(2026, 10, 7)),
        contains('2026. 10. 07. óta'),
      );
    });
  }

  for (final failure in ApiFailure.values) {
    testWidgets('the ${failure.name} icon is rounded and strip-sized, 18 '
        '(IK1, IK3)', (tester) async {
      await pumpBanner(tester, failure, Brightness.light);

      expect(
        failure.icon,
        {
          ApiFailure.noConnection: Icons.signal_wifi_off_rounded,
          ApiFailure.serverError: Icons.cloud_off_rounded,
        }[failure],
      );
      expect(tester.getSize(find.byIcon(failure.icon)), const Size(18, 18));
    });
  }
}
