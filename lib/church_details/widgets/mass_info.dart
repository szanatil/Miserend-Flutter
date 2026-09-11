import 'package:flutter/material.dart';
import 'package:miserend/database/cache/cached_mass.dart';
import 'package:miserend/extentions.dart';
import 'package:miserend/widgets/miserend_text.dart';

/// Decides whether a mass carries anything worth opening, and shows it.
class MassInfo {
  /// What the API says about an ordinary mass. Measured against live data:
  /// almost every occurrence carries one of these and nothing else, so a chip
  /// showing one of them has nothing to reveal.
  static const Set<String> _generic = {
    'szentmise',
    'mise',
    'római katolikus szentmise',
    'romai katolikus szentmise',
  };

  static bool isMeaningful(String? info) {
    final text = MiserendText.normalize(info);
    if (text.isEmpty) {
      return false;
    }
    return !_generic.contains(text.toLowerCase());
  }

  static void show(BuildContext context, CachedMass mass) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  TimeOfDay.fromDateTime(mass.time).to24hours(),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(MiserendText.normalize(mass.info)),
              ],
            ),
          ),
        );
      },
    );
  }
}
