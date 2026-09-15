import 'package:flutter/material.dart';
import 'package:miserend/location_provider.dart';

/// What a screen that needs the user's position shows instead, one message
/// and one way out per reason (CONTEXT.md, „Helyzet nem elérhető").
class PositionUnavailableView extends StatelessWidget {
  const PositionUnavailableView({
    super.key,
    required this.reason,
    required this.purpose,
    required this.location,
    required this.onRetry,
  });

  final PositionUnavailableReason reason;

  /// What the position is needed for, as the sentence opens: "A közeli
  /// templomokhoz", "A legközelebbi misékhez".
  final String purpose;

  /// Opens the settings pages.
  final LocationProvider location;

  /// Asks for the position again, and with it the permission.
  final VoidCallback onRetry;

  /// The message for [reason]; the map's SnackBar says the same.
  static String message(PositionUnavailableReason reason, String purpose) {
    return switch (reason) {
      PositionUnavailableReason.permissionDenied =>
        '$purpose engedélyezd a helyadatot.',
      PositionUnavailableReason.permissionDeniedForever =>
        '$purpose engedélyezd a helyadatot a telefon beállításaiban.',
      PositionUnavailableReason.serviceDisabled =>
        '$purpose kapcsold be a helymeghatározást.',
      PositionUnavailableReason.noFreshFix =>
        'Nem sikerült meghatározni a helyzetedet.',
    };
  }

  /// The button's label and action for [reason], or null when there is
  /// nothing to press — no fix in time is retried by pulling the list down.
  static (String, VoidCallback)? action(PositionUnavailableReason reason,
      LocationProvider location, VoidCallback onRetry) {
    return switch (reason) {
      PositionUnavailableReason.permissionDenied => ('Engedélyezés', onRetry),
      PositionUnavailableReason.permissionDeniedForever => (
          'Beállítások megnyitása',
          location.openAppSettings
        ),
      PositionUnavailableReason.serviceDisabled => (
          'Beállítások megnyitása',
          location.openLocationSettings
        ),
      PositionUnavailableReason.noFreshFix => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final button = action(reason, location, onRetry);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message(reason, purpose), textAlign: TextAlign.center),
            if (button != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: button.$2, child: Text(button.$1)),
            ],
          ],
        ),
      ),
    );
  }
}
