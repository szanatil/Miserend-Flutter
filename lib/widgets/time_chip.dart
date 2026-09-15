import 'package:flutter/material.dart';
import 'package:miserend/colors.dart';
import 'package:miserend/extentions.dart';

class TimeChip extends StatelessWidget {
  const TimeChip({
    super.key,
    required this.time,
    this.onTap,
    this.hasInfo = false,
  });

  final TimeOfDay? time;

  /// Only set where there is something to open; most masses carry nothing but
  /// the generic "Római katolikus Szentmise", and a chip that opens an empty
  /// popup teaches people not to tap the ones that matter.
  final VoidCallback? onTap;

  /// Draws the marker that says this chip has more behind it.
  final bool hasInfo;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      time?.to24hours() ?? "?",
      style: Theme.of(context).textTheme.bodyMedium?.apply(color: Colors.white),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Material(
        color: CustomColors.accent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child:
                hasInfo
                    ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        label,
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.info_outline,
                          size: 14,
                          color: Colors.white,
                        ),
                      ],
                    )
                    : label,
          ),
        ),
      ),
    );
  }
}
