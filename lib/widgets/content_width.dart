import 'package:flutter/material.dart';

/// Keeps a list or a form at most [maxWidth] wide, centred, on a screen wider
/// than a phone: a tablet, or a phone on its side (DESIGN.md EL3). It widens
/// the padding the scroll view gets rather than narrowing the view, so that
/// the margins still scroll it and its scroll bar stays at the screen's edge.
class ContentWidth extends StatelessWidget {
  const ContentWidth({
    super.key,
    this.padding = EdgeInsets.zero,
    required this.builder,
  });

  /// The widest a list or a form gets (DESIGN.md EL3).
  static const double maxWidth = 640;

  /// The padding on a phone.
  final EdgeInsets padding;

  /// Builds the scroll view with the padding for the width it is given.
  final Widget Function(BuildContext context, EdgeInsets padding) builder;

  /// [padding] widened on both sides, so that what it pads on a screen
  /// [width] wide is at most [maxWidth] wide and stands in the middle.
  static EdgeInsets widen(EdgeInsets padding, double width) {
    final extra = (width - padding.horizontal - maxWidth) / 2;
    if (extra <= 0) return padding;
    return padding.copyWith(
      left: padding.left + extra,
      right: padding.right + extra,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder:
          (context, constraints) =>
              builder(context, widen(padding, constraints.maxWidth)),
    );
  }
}
