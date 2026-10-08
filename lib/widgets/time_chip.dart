import 'package:flutter/material.dart';
import 'package:miserend/extentions.dart';
import 'package:miserend/theme/miserend_colors.dart';
import 'package:miserend/theme/tokens.dart';

/// The time of a mass, in the orange that marks a time and nothing else
/// (DESIGN.md KO3, SZ4). It stays in a container of its own: orange text on a
/// surface would not be legible.
class TimeChip extends StatelessWidget {
  const TimeChip({
    super.key,
    required this.time,
    this.onTap,
    this.hasInfo = false,
    this.ongoing = false,
  }) : _label = null;

  /// Stands in for the masses a row has no room for. It opens nothing of its
  /// own: whatever the row sits on leads to where every mass is listed.
  const TimeChip.more({super.key})
    : time = null,
      onTap = null,
      hasInfo = false,
      ongoing = false,
      _label = moreLabel;

  /// The text of [TimeChip.more].
  static const String moreLabel = '…';

  static const EdgeInsets _padding = EdgeInsets.symmetric(
    horizontal: Spacing.s,
    vertical: Spacing.xs,
  );

  static const ShapeBorder _shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(Radii.s)),
  );

  /// The (i) marker's size, a chip's icon size (IK3).
  static const double _iconSize = 18;

  final TimeOfDay? time;

  final String? _label;

  /// Only set where there is something to open; most masses carry nothing but
  /// the generic "Római katolikus Szentmise", and a chip that opens an empty
  /// popup teaches people not to tap the ones that matter.
  final VoidCallback? onTap;

  /// Draws the marker that says this chip has more behind it.
  final bool hasInfo;

  /// The mass is going on now (CONTEXT.md, „Épp most tartó mise"): the chip
  /// turns the filled orange.
  final bool ongoing;

  /// The width a chip without the (i) marker takes for [label], so that a row
  /// can fit chips by width before laying them out.
  static double widthOf(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: _textStyle(context)),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width + _padding.horizontal;
    painter.dispose();
    return width;
  }

  /// As strong as the church name beside it and bolder, so that the time
  /// leads the card (TI3); the figures line up from chip to chip (TI4).
  static TextStyle? _textStyle(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = Theme.of(
      context,
    ).extension<MiserendColors>()!.occasionTimeColors(ongoing: ongoing);

    final label = Text(
      _label ?? time?.to24hours() ?? '?',
      style: _textStyle(context)?.copyWith(color: foreground),
    );
    final content = Padding(
      padding: _padding,
      child:
          hasInfo
              ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  label,
                  const SizedBox(width: Spacing.s),
                  Icon(
                    Icons.info_outline_rounded,
                    size: _iconSize,
                    color: foreground,
                  ),
                ],
              )
              : label,
    );

    final onTap = this.onTap;
    return Material(
      color: background,
      shape: _shape,
      clipBehavior: Clip.antiAlias,
      // A chip that opens nothing gives no touch feedback (KO4).
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}
