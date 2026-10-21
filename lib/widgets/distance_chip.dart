import 'package:flutter/material.dart';
import 'package:miserend/straight_line_distance.dart';
import 'package:miserend/theme/tokens.dart';

/// The straight-line distance to a church (CONTEXT.md, „Légvonal-távolság"),
/// the same on the church card and on the nearest masses' row: a data chip
/// in the supplementary data's colours (DESIGN.md KO4, SZ4). It is opaque, so
/// it reads on a photo, which may be as light or as dark as anything.
class DistanceChip extends StatelessWidget {
  const DistanceChip({super.key, required this.km});

  final double km;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: scheme.surfaceContainerHighest,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(Radii.s)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.s,
          vertical: Spacing.xs,
        ),
        child: Text(
          formatDistance(km),
          // The figures line up from card to card (TI4).
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: scheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
