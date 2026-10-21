import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/api/api_result.dart';
import 'package:miserend/api/api_status.dart';

void main() {
  const answered = ApiSuccess<Object?>(null);
  const offline = ApiFailed<Object?>(ApiFailure.noConnection);
  const broken = ApiFailed<Object?>(ApiFailure.serverError);

  group('calls recorded as one', () {
    test('are answered when any of them was, in whatever order', () {
      for (final results in [
        [answered, offline, broken],
        [offline, broken, answered],
        [broken, answered, offline],
      ]) {
        final status = ApiStatus()..record(offline);
        status.recordAll(results);
        expect(status.value, isNull, reason: '$results');
      }
    });

    test('fail when all of them did', () {
      expect(
        (ApiStatus()..recordAll([broken, broken])).value,
        ApiFailure.serverError,
      );
      expect(
        (ApiStatus()..recordAll([offline, offline])).value,
        ApiFailure.noConnection,
      );
    });

    test('fail with no connection when any got no answer, in whatever '
        'order', () {
      expect(
        (ApiStatus()..recordAll([broken, offline])).value,
        ApiFailure.noConnection,
      );
      expect(
        (ApiStatus()..recordAll([offline, broken])).value,
        ApiFailure.noConnection,
      );
    });

    test('leave the status as it was when there were none', () {
      final status = ApiStatus()..record(broken);
      status.recordAll(const []);
      expect(status.value, ApiFailure.serverError);
    });
  });

  test('a call log keeps the calls and tells no one', () {
    final log = ApiCallLog();
    var told = 0;
    log.addListener(() => told++);

    log
      ..record(offline)
      ..record(answered);

    expect(log.results, [offline, answered]);
    expect(log.value, isNull);
    expect(told, 0);
  });
}
