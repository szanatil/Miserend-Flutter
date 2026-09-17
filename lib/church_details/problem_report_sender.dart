import 'package:flutter/foundation.dart';
import 'package:miserend/api/api_result.dart';
import 'package:miserend/api/miserend_api_client.dart';
import 'package:miserend/api/problem_type.dart';

/// Sends what the problem report page collected (spec 0009, „Hibajelentés: a
/// kérés"). A class of its own so the page can be pumped with a fake one.
class ProblemReportSender {
  ProblemReportSender({MiserendApiClient? api})
    : _api = api ?? MiserendApiClient();

  final MiserendApiClient _api;

  /// Sends the report through [MiserendApiClient.report], and logs why when
  /// it did not get through.
  Future<ApiResult<void>> send({
    required int churchId,
    required ProblemType type,
    required String text,
    String? email,
    required DateTime dataAsOf,
  }) async {
    final result = await _api.report(
      churchId: churchId,
      type: type,
      text: text,
      email: email,
      dataAsOf: dataAsOf,
    );
    if (result case ApiFailed(:final failure)) {
      // The reason only: the text and the address are the user's, and
      // debugPrint writes in release builds too (B3).
      debugPrint('Problem report not sent: ${failure.name}');
    }
    return result;
  }
}
