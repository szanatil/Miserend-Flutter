import 'package:flutter/material.dart';
import 'package:miserend/theme/tokens.dart';
import 'package:miserend/widgets/section_card.dart';
import 'package:miserend/widgets/status_badge.dart';

/// Announces that confession is being heard at this very moment: a state, so
/// a state badge on an ordinary card (DESIGN.md KO6), not an orange card.
///
/// The tile has no negative form on purpose. `gyontatas` reports a physical
/// switch in the confessional over LoRaWAN, and the v4 API returns a bare
/// boolean, so a switch that is off and a church with no switch installed both
/// arrive as `false` — and almost every church has no switch (338 of 338
/// sampled). "Most nem gyóntatnak" would therefore be a claim we cannot make
/// about nearly every church on the map.
class ConfessionTile extends StatelessWidget {
  const ConfessionTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: SectionCard.margin,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.l),
        child: Row(
          children: [
            Icon(
              Icons.record_voice_over_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: Spacing.s),
            const Flexible(child: StatusBadge(label: 'Most gyóntatnak')),
          ],
        ),
      ),
    );
  }
}
