import 'package:flutter/material.dart';
import 'package:miserend/location_provider.dart';

/// The way out of a **Helyzet nem elérhető** reason: what the button says,
/// what it does, and whether it hands the user over to the phone's settings.
/// The last one travels with the other two because a screen that stays behind
/// has to ask for the position again when the user comes back — the in-app
/// permission prompt needs no such thing.
class PositionAction {
  const PositionAction(
    this.label,
    this.onPressed, {
    this.sendsToSettings = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool sendsToSettings;
}

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

  /// The message for [reason]; the map's strip says the same.
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

  /// The way out of [reason], or null when there is nothing to press — no fix
  /// in time is retried by pulling the list down.
  static PositionAction? action(
    PositionUnavailableReason reason,
    LocationProvider location,
    VoidCallback onRetry,
  ) {
    return switch (reason) {
      PositionUnavailableReason.permissionDenied => PositionAction(
        'Engedélyezés',
        onRetry,
      ),
      PositionUnavailableReason.permissionDeniedForever => PositionAction(
        'Beállítások megnyitása',
        location.openAppSettings,
        sendsToSettings: true,
      ),
      PositionUnavailableReason.serviceDisabled => PositionAction(
        'Beállítások megnyitása',
        location.openLocationSettings,
        sendsToSettings: true,
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
              FilledButton(
                onPressed: button.onPressed,
                child: Text(button.label),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
