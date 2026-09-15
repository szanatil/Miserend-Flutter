/// Why an API call produced no answer. The two are told apart because the
/// user has to do different things about them (CONTEXT.md, „Nincs kapcsolat",
/// „Szerverhiba").
enum ApiFailure {
  /// The request never reached the server: no network, data use not allowed,
  /// airplane mode, or a timeout.
  noConnection,

  /// The server answered, but not with something usable: an HTTP error, an
  /// error flag in the payload, or JSON that does not parse.
  serverError,
}

/// The outcome of one API call. A successful answer may well be empty — "no
/// mass on this day", "no church found" — and that is not a failure.
sealed class ApiResult<T> {
  const ApiResult();
}

final class ApiSuccess<T> extends ApiResult<T> {
  const ApiSuccess(this.value);

  final T value;
}

final class ApiFailed<T> extends ApiResult<T> {
  const ApiFailed(this.failure);

  final ApiFailure failure;
}
