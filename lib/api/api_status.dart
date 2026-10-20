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

  void record(ApiResult<Object?> result) =>
      value = switch (result) {
        ApiSuccess() => null,
        ApiFailed(:final failure) => failure,
      };
}
