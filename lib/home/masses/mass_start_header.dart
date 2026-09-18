import 'package:flutter/material.dart';
import 'package:miserend/api/nearby_masses_item.dart';
import 'package:miserend/colors.dart';
import 'package:miserend/extentions.dart';
import 'package:miserend/home/masses/nearest_masses.dart';

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
    final textTheme = Theme.of(context).textTheme;
    // The two exclude each other: an ongoing mass has no time until start.
    final ongoing = isOngoing(mass, now);
    final until = ongoing ? null : timeUntilStart(mass.start, now);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              Text(
                TimeOfDay.fromDateTime(mass.start).to24hours(),
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: CustomColors.accent,
                ),
              ),
              if (ongoing)
                const _OngoingBadge()
              else if (until != null)
                Text(
                  until,
                  style: textTheme.bodyLarge?.apply(color: Colors.black54),
                ),
            ],
          ),
          const Divider(height: 8, thickness: 1, color: Colors.black26),
        ],
      ),
    );
  }
}

/// Marks an ongoing mass in place of its time until start (CONTEXT.md,
/// „Épp most tartó mise").
class _OngoingBadge extends StatelessWidget {
  const _OngoingBadge();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Épp most tart',
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: colors.onPrimaryContainer),
      ),
    );
  }
}
