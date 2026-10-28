import 'package:flutter/material.dart';
import 'package:miserend/widgets/notice_strip.dart';

/// The map's **tájékoztató szalag** (DESIGN.md KO7): no church in view, and
/// the bootstrap import has not run, which may be why (spec 0015,
/// „Tájékoztatás"). It informs rather than warns, and has neither a button
/// nor a close: the user chose not to download, and it follows the area in
/// view by itself.
class MissingChurchesBanner extends StatelessWidget {
  const MissingChurchesBanner({super.key});

  static const String message =
      'Itt most nincs megjeleníthető templom. Lehet, hogy azért, mert nem '
      'töltötted le az összes templom adatait; a letöltést a Névjegyen '
      'indíthatod el.';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return NoticeStrip(
      color: scheme.surfaceContainerHigh,
      icon: Icons.info_outline_rounded,
      iconColor: scheme.onSurfaceVariant,
      textColor: scheme.onSurfaceVariant,
      text: message,
      actions: const [],
    );
  }
}
