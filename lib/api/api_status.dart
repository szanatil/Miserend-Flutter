import 'package:flutter/foundation.dart';
import 'package:miserend/api/api_result.dart';

/// How the app's last API call ended: why it got no answer, or null when it
/// got one. A call failing and nothing having answered since is as close as
/// the app comes to knowing it is offline — it cannot watch the network
/// (see `StaleDataRetry`) — and the Részletes kereső's day condition is not
/// offered then (CONTEXT.md, „Részletes kereső").
class ApiStatus extends ValueNotifier<ApiFailure?> {
  ApiStatus() : super(null);

  /// The app's, which every client reports to unless a test hands in its
  /// own.
  static final ApiStatus shared = ApiStatus();

  void record(ApiResult<Object?> result) => value = _failureOf(result);

  /// Records [results], calls made together, as one call: answered if any of
  /// them was, else failed — with no connection if any of them got no answer
  /// at all. A Részletes kereső page makes its calls in parallel, so which
  /// of them answers last is chance, and must not decide (spec 0010, „Oldal"; #92).
  void recordAll(List<ApiResult<Object?>> results) {
    if (results.isEmpty) return;
    final failures = results.map(_failureOf);
    value =
        failures.contains(null)
            ? null
            : failures.contains(ApiFailure.noConnection)
            ? ApiFailure.noConnection
            : ApiFailure.serverError;
  }

  static ApiFailure? _failureOf(ApiResult<Object?> result) => switch (result) {
    ApiSuccess() => null,
    ApiFailed(:final failure) => failure,
  };
}

/// Keeps the calls reported to it instead of telling anyone, so that they
/// can reach an [ApiStatus] together, through [ApiStatus.recordAll].
class ApiCallLog extends ApiStatus {
  /// The calls reported, in the order they ended.
  final List<ApiResult<Object?>> results = [];

  @override
  void record(ApiResult<Object?> result) => results.add(result);
}
