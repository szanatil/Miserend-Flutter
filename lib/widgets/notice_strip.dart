import 'package:flutter/material.dart';
import 'package:miserend/theme/tokens.dart';

/// The shape every informational strip takes — a tinted band with a small
/// icon, one line of prose and its buttons on the right. Only the look lives
/// here: each strip keeps its own domain state, and two of them can be up at
/// once (no connection and no position), so they have to read as one family.
class NoticeStrip extends StatelessWidget {
  const NoticeStrip({
    super.key,
    required this.color,
    required this.icon,
    required this.iconColor,
    required this.textColor,
    required this.text,
    required this.actions,
  });

  final Color color;
  final IconData icon;

  /// Carries the meaning as much as [icon] does — a server error's amber
  /// against the quieter grey of what merely informs.
  final Color iconColor;

  /// The `on…` role of [color], so the line reads in both modes (SZ4).
  final Color textColor;

  final String text;

  /// What the user can do about it, at the end of the strip.
  final List<Widget> actions;

  static const double _iconSize = 18;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      child: Padding(
        padding: const EdgeInsets.only(left: Spacing.l),
        child: Row(
          children: [
            Icon(icon, size: _iconSize, color: iconColor),
            const SizedBox(width: Spacing.s),
            Expanded(
              child: Text(
                text,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: textColor),
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}
