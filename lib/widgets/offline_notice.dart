import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:miserend/api/api_result.dart';

/// What the user can do to get live data again, which depends on the screen:
/// a list is pulled down, a single church is opened again.
enum RetryHint { pullList, reopenChurch }

/// The wording and colours shared by every place that marks data as not live
/// (CONTEXT.md, „Nincs kapcsolat", „Szerverhiba"): the lists' banner, the map's
/// church card and the details page.
class OfflineNotice {
  /// Behind what a server error leaves on screen. A user with signal does not
  /// expect stale data, so it has to stand out more than no connection does.
  static const Color serverErrorTint = Color(0xFFFFE0B2);

  /// The (i) icon's colour for a server error, readable on [serverErrorTint].
  static const Color serverErrorAccent = Color(0xFFB45309);

  static final DateFormat _date = DateFormat('yyyy. MM. dd');

  /// The explanation the (i) opens. [asOf] is how old the data is; null only
  /// when not even the bootstrap import recorded a date.
  static String explanation(
      ApiFailure failure, DateTime? asOf, RetryHint hint) {
    final state = asOf == null ? '' : ', ${_date.format(asOf)}-i';
    switch (failure) {
      case ApiFailure.noConnection:
        final retry = switch (hint) {
          RetryHint.pullList => 'húzd le a listát',
          RetryHint.reopenChurch => 'nyisd meg újra a templomot',
        };
        return 'Az adatok a telefonon tárolt$state állapotot mutatják. '
            'Frissítéshez kapcsold be az adatkapcsolatot, vagy ellenőrizd, '
            'hogy a Miserend használhat-e mobilnetet a telefon '
            'beállításaiban, majd $retry.';
      case ApiFailure.serverError:
        return asOf == null
            ? 'A miserend.hu jelenleg nem elérhető, az adatok a telefonon '
                'tárolt állapotot mutatják.'
            : 'A miserend.hu jelenleg nem elérhető, az adatok '
                '${_date.format(asOf)}-i állapotot mutatnak.';
    }
  }

  static Future<void> show(BuildContext context, ApiFailure failure,
      DateTime? asOf, RetryHint hint) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(explanation(failure, asOf, hint)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Rendben'),
          ),
        ],
      ),
    );
  }
}

/// The (i) that marks data as not live and opens [OfflineNotice.explanation].
class OfflineInfoButton extends StatelessWidget {
  const OfflineInfoButton({
    super.key,
    required this.failure,
    required this.asOf,
    required this.hint,
  });

  final ApiFailure failure;
  final DateTime? asOf;
  final RetryHint hint;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.info_outline),
      color: failure == ApiFailure.serverError
          ? OfflineNotice.serverErrorAccent
          : Colors.black54,
      tooltip: 'Nem friss adat',
      visualDensity: VisualDensity.compact,
      onPressed: () => OfflineNotice.show(context, failure, asOf, hint),
    );
  }
}

/// The strip above a list or the details page that shows it is not live,
/// once, rather than on every row. There is no closing it: someone who never
/// goes online sees it for good, as information rather than as an error.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    super.key,
    required this.failure,
    required this.asOf,
    this.hint = RetryHint.pullList,
  });

  final ApiFailure failure;
  final DateTime? asOf;
  final RetryHint hint;

  @override
  Widget build(BuildContext context) {
    final serverError = failure == ApiFailure.serverError;
    return Material(
      color: serverError ? OfflineNotice.serverErrorTint : const Color(0xFFEEEEEE),
      child: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Row(
          children: [
            Icon(
              serverError ? Icons.cloud_off : Icons.signal_wifi_off,
              size: 18,
              color: serverError ? OfflineNotice.serverErrorAccent : Colors.black54,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                serverError
                    ? 'A miserend.hu nem elérhető, tárolt adatok'
                    : 'Nincs kapcsolat, tárolt adatok',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            OfflineInfoButton(failure: failure, asOf: asOf, hint: hint),
          ],
        ),
      ),
    );
  }
}
