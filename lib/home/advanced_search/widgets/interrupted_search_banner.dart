import 'package:flutter/material.dart';
import 'package:miserend/api/api_result.dart';
import 'package:miserend/theme/adaptive.dart';
import 'package:miserend/widgets/notice_strip.dart';
import 'package:miserend/widgets/offline_notice.dart';

/// The strip above a search the API stopped answering, even after its
/// retries (CONTEXT.md, „Részletes kereső", megszakadt keresés). Unlike the
/// lists' [OfflineBanner] it does not try again by itself: the list is not
/// filled in from the cache, so it would grow under the user's eyes, and a
/// search goes on only from its start (DESIGN.md KO7).
class InterruptedSearchBanner extends StatelessWidget {
  const InterruptedSearchBanner({
    super.key,
    required this.failure,
    required this.foundAny,
    required this.onRestart,
  });

  final ApiFailure failure;

  /// Whether the list holds churches found before the search stopped.
  final bool foundAny;

  /// Runs the same search again from its start.
  final VoidCallback onRestart;

  static const String _explanation =
      'Kapcsolat nélkül a keresés nem folytatható. Ha újra van kapcsolat, '
      'indítsd újra az Újra gombbal.';

  @override
  Widget build(BuildContext context) {
    return NoticeStrip(
      color: failure.tint(context),
      icon: failure.icon,
      iconColor: failure.iconColor(context),
      textColor: failure.textColor(context),
      text:
          foundAny
              ? 'A keresés megszakadt, a lista nem teljes.'
              : switch (failure) {
                ApiFailure.noConnection =>
                  'A keresés nem sikerült, nincs kapcsolat.',
                ApiFailure.serverError =>
                  'A keresés nem sikerült, a miserend.hu nem elérhető.',
              },
      actions: [
        TextButton(onPressed: onRestart, child: const Text('Újra')),
        IconButton(
          icon: const Icon(Icons.info_outline_rounded),
          color: failure.iconColor(context),
          tooltip: 'Bővebben',
          onPressed:
              () => showMiserendDialog<void>(
                context,
                content: _explanation,
                actions: const [MiserendDialogAction('Rendben', null)],
              ),
        ),
      ],
    );
  }
}
