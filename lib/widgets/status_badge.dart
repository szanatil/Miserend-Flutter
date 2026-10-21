import 'package:flutter/material.dart';
import 'package:miserend/theme/miserend_colors.dart';
import 'package:miserend/theme/tokens.dart';

/// A state badge (DESIGN.md KO6): says that something is different *now*,
/// in words as well as colour (AM2), and is never tapped. Every state the app
/// marks so far is an occasion going on now — „Épp most tart", „Most
/// gyóntatnak" — so it wears the filled orange of an ongoing occasion (SZ4).
/// The label is what a screen reader says.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<MiserendColors>()!;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.occasionTime,
        shape: Radii.full,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.s,
          vertical: Spacing.xs,
        ),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: colors.onOccasionTime),
        ),
      ),
    );
  }
}
