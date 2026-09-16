import 'package:flutter/material.dart';
import 'package:miserend/colors.dart';
import 'package:miserend/location_provider.dart';
import 'package:miserend/widgets/notice_strip.dart';
import 'package:miserend/widgets/position_unavailable_view.dart';

/// The map's own **Helyzet nem elérhető** state (CONTEXT.md), as a strip at
/// the foot of the page. The position-bound lists give the state a whole
/// screen; the map is useful without a position, so here it only takes a
/// [NoticeStrip], the shape the no-connection banner takes too.
///
/// It used to be a SnackBar, which the root ScaffoldMessenger held above the
/// tabs, and which Flutter makes persistent as soon as it has an action, so it
/// never went away on its own (issue #23).
class PositionUnavailableBanner extends StatelessWidget {
  const PositionUnavailableBanner({
    super.key,
    required this.reason,
    required this.location,
    required this.onRetry,
    required this.onClose,
  });

  final PositionUnavailableReason reason;

  /// Opens the settings pages.
  final LocationProvider location;

  /// Asks for the position again, and with it the permission.
  final VoidCallback onRetry;

  /// Puts the strip away without settling anything: the map works without a
  /// position, so the user may dismiss the question rather than answer it.
  final VoidCallback onClose;

  /// What the position is needed for here, as the sentence opens.
  static const String _purpose = 'A helyzeted mutatásához';

  @override
  Widget build(BuildContext context) {
    final button = PositionUnavailableView.action(reason, location, onRetry);
    return NoticeStrip(
      color: CustomColors.noticeTint,
      icon: Icons.location_off,
      iconColor: Colors.black54,
      text: PositionUnavailableView.message(reason, _purpose),
      actions: [
        if (button != null)
          TextButton(
            // Nothing to tell the page: it checks the position again
            // whenever it comes back into view (map_page.dart).
            onPressed: button.onPressed,
            child: Text(button.label),
          ),
        IconButton(
          icon: const Icon(Icons.close),
          color: Colors.black54,
          tooltip: 'Bezárás',
          visualDensity: VisualDensity.compact,
          onPressed: onClose,
        ),
      ],
    );
  }
}
