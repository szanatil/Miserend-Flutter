import 'package:flutter/material.dart';
import 'package:miserend/colors.dart';
import 'package:miserend/extentions.dart';

class TimeChip extends StatelessWidget {
  const TimeChip({
    super.key,
    required this.time,
    this.onTap,
    this.hasInfo = false,
  }) : _label = null;

  /// Stands in for the masses a row has no room for. It opens nothing of its
  /// own: whatever the row sits on leads to where every mass is listed.
  const TimeChip.more({super.key})
    : time = null,
      onTap = null,
      hasInfo = false,
      _label = moreLabel;

  /// Around the label on every side; a row that fits chips by width counts it.
  static const double padding = 4;

  /// The text of [TimeChip.more].
  static const String moreLabel = '…';

  final TimeOfDay? time;

  final String? _label;

  /// Only set where there is something to open; most masses carry nothing but
  /// the generic "Római katolikus Szentmise", and a chip that opens an empty
  /// popup teaches people not to tap the ones that matter.
  final VoidCallback? onTap;

  /// Draws the marker that says this chip has more behind it.
  final bool hasInfo;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      _label ?? time?.to24hours() ?? '?',
      style: Theme.of(context).textTheme.bodyMedium?.apply(color: Colors.white),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Material(
        color: CustomColors.accent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(padding),
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
