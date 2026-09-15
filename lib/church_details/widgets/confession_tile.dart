import 'package:flutter/material.dart';
import 'package:miserend/colors.dart';

/// Announces that confession is being heard at this very moment.
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
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: CustomColors.accent,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.record_voice_over, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Most gyóntatnak!',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.apply(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
