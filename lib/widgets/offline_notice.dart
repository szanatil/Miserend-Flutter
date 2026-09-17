import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:miserend/api/api_result.dart';
import 'package:miserend/colors.dart';
import 'package:miserend/widgets/notice_strip.dart';
import 'package:miserend/widgets/stale_data_retry.dart';

/// The explanation shared by every place that marks data as not live
/// (CONTEXT.md, „Nincs kapcsolat", „Szerverhiba"): the lists' banner, the map's
/// church card and the details page. Their colours and icons are
/// [OfflineLook]'s.
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

/// How each failure looks, wherever data is marked as not live. A server
/// error stands out more than no connection: a user with signal does not
/// expect stale data (CONTEXT.md, „Szerverhiba"). Kept in one place so that
/// the banners, the (i) buttons and the map's card cannot drift apart.
extension OfflineLook on ApiFailure {
  /// The background of a strip that marks the data.
  Color get tint => switch (this) {
    ApiFailure.noConnection => CustomColors.noticeTint,
    ApiFailure.serverError => CustomColors.serverErrorTint,
  };

  /// The background of the map's church card, which keeps its own colour
  /// unless the server failed.
  Color? get cardTint => switch (this) {
    ApiFailure.noConnection => null,
    ApiFailure.serverError => CustomColors.serverErrorTint,
  };

  IconData get icon => switch (this) {
    ApiFailure.noConnection => Icons.signal_wifi_off,
    ApiFailure.serverError => Icons.cloud_off,
  };

  /// The colour of the icons, readable on [tint].
  Color get iconColor => switch (this) {
    ApiFailure.noConnection => Colors.black54,
    ApiFailure.serverError => CustomColors.serverErrorAccent,
  };
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
      color: failure.iconColor,
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
    return StaleDataRetry(
      onRetry: onRetry,
      child: NoticeStrip(
        color: failure.tint,
        icon: failure.icon,
        iconColor: failure.iconColor,
        text: switch (failure) {
          ApiFailure.noConnection => 'Nincs kapcsolat, tárolt adatok',
          ApiFailure.serverError => 'A miserend.hu nem elérhető, tárolt adatok',
        },
        actions: [OfflineInfoButton(failure: failure, asOf: asOf)],
      ),
    );
  }
}
