import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:miserend/api/api_result.dart';
import 'package:miserend/colors.dart';
import 'package:miserend/widgets/notice_strip.dart';
import 'package:miserend/widgets/stale_data_retry.dart';

/// The wording and colours shared by every place that marks data as not live
/// (CONTEXT.md, „Nincs kapcsolat", „Szerverhiba"): the lists' banner, the map's
/// church card and the details page.
class OfflineNotice {
  static final DateFormat _date = DateFormat('yyyy. MM. dd');

  /// The explanation the (i) opens. [asOf] is how old the data is; null only
  /// when not even the bootstrap import recorded a date.
  static String explanation(ApiFailure failure, DateTime? asOf) {
    final state = asOf == null ? '' : ', ${_date.format(asOf)}-i';
    switch (failure) {
      case ApiFailure.noConnection:
        // No instruction to pull or reopen: the screen retries by itself
        // (StaleDataRetry), so the only thing left for the user to do is to
        // restore the connection.
        return 'Az adatok a telefonon tárolt$state állapotot mutatják. '
            'Kapcsold be az adatkapcsolatot, vagy ellenőrizd, hogy a '
            'Miserend használhat-e mobilnetet a telefon beállításaiban — '
            'amint újra van kapcsolat, a képernyő magától frissül.';
      case ApiFailure.serverError:
        return asOf == null
            ? 'A miserend.hu jelenleg nem elérhető, az adatok a telefonon '
                'tárolt állapotot mutatják.'
            : 'A miserend.hu jelenleg nem elérhető, az adatok '
                '${_date.format(asOf)}-i állapotot mutatnak.';
    }
  }

  static Future<void> show(
    BuildContext context,
    ApiFailure failure,
    DateTime? asOf,
  ) {
    return showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            content: Text(explanation(failure, asOf)),
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
  });

  final ApiFailure failure;
  final DateTime? asOf;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.info_outline),
      color:
          failure == ApiFailure.serverError
              ? CustomColors.serverErrorAccent
              : Colors.black54,
      tooltip: 'Nem friss adat',
      visualDensity: VisualDensity.compact,
      onPressed: () => OfflineNotice.show(context, failure, asOf),
    );
  }
}

/// The strip above a list or the details page that shows it is not live,
/// once, rather than on every row. There is no closing it: someone who never
/// goes online sees it for good, as information rather than as an error.
///
/// While it is up, it keeps asking the screen to fetch again, so that a phone
/// coming back online heals the screen without the user doing anything.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    super.key,
    required this.failure,
    required this.asOf,
    required this.onRetry,
  });

  final ApiFailure failure;
  final DateTime? asOf;

  /// Fetches again, for as long as this strip is on screen.
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final serverError = failure == ApiFailure.serverError;
    return StaleDataRetry(
      onRetry: onRetry,
      child: NoticeStrip(
        color:
            serverError
                ? CustomColors.serverErrorTint
                : CustomColors.noticeTint,
        icon: serverError ? Icons.cloud_off : Icons.signal_wifi_off,
        iconColor:
            serverError ? CustomColors.serverErrorAccent : Colors.black54,
        text:
            serverError
                ? 'A miserend.hu nem elérhető, tárolt adatok'
                : 'Nincs kapcsolat, tárolt adatok',
        actions: [OfflineInfoButton(failure: failure, asOf: asOf)],
      ),
    );
  }
}
