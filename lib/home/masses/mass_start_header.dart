import 'package:flutter/material.dart';
import 'package:miserend/api/nearby_masses_item.dart';
import 'package:miserend/extentions.dart';
import 'package:miserend/home/masses/nearest_masses.dart';
import 'package:miserend/theme/miserend_colors.dart';
import 'package:miserend/theme/tokens.dart';
import 'package:miserend/widgets/status_badge.dart';

/// Heads the masses starting together with [mass] on the Misék tab: on this
/// tab *when* decides (spec 0008), so the start leads, followed by the time
/// until it or the ongoing mark, and a line under them sets the block apart.
class MassStartHeader extends StatelessWidget {
  const MassStartHeader({super.key, required this.mass, required this.now});

  /// One of the masses under the header; they all start when it does.
  final NearbyMassesItem mass;

  /// The moment the list was selected at, for the time until start and the
  /// ongoing mark.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final scheme = theme.colorScheme;
    // The two exclude each other: an ongoing mass has no time until start.
    final ongoing = isOngoing(mass, now);
    final until = ongoing ? null : timeUntilStart(mass.start, now);
    final (timeBackground, timeForeground) = theme
        .extension<MiserendColors>()!
        .occasionTimeColors(ongoing: ongoing);

    return Padding(
      padding: const EdgeInsets.only(top: Spacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Spacing.s,
            runSpacing: Spacing.xs,
            children: [
              // Orange text would not be legible on the page, so the start
              // stands in its own container, as on a time chip (SZ4).
              DecoratedBox(
                decoration: ShapeDecoration(
                  color: timeBackground,
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
                    TimeOfDay.fromDateTime(mass.start).to24hours(),
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: timeForeground,
                    ),
                  ),
                ),
              ),
              // CONTEXT.md, „Épp most tartó mise".
              if (ongoing)
                const StatusBadge(label: 'Épp most tart')
              else if (until != null)
                Text(
                  until,
                  style: textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          Divider(
            height: Spacing.s,
            thickness: 1,
            color: scheme.outlineVariant,
          ),
        ],
      ),
    );
  }
}
