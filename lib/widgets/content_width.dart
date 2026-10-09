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

  /// The widest a list or a form gets, and the widest one column of cards
  /// gets (DESIGN.md EL3).
  static const double maxWidth = 640;

  /// The narrowest screen that puts cards in two columns (DESIGN.md EL3).
  static const double twoColumnsFrom = 840;

  /// The narrowest screen that puts cards in three columns, the most there
  /// are (DESIGN.md EL3).
  static const double threeColumnsFrom = 1200;

  /// The padding on a phone.
  final EdgeInsets padding;

  /// Builds the scroll view with the padding for the width it is given.
  final Widget Function(BuildContext context, EdgeInsets padding) builder;

  /// How many columns of cards a screen [width] wide holds (DESIGN.md EL3).
  static int columnsFor(double width) {
    if (width >= threeColumnsFrom) return 3;
    if (width >= twoColumnsFrom) return 2;
    return 1;
  }

  /// [padding] widened on both sides, so that what it pads on a screen
  /// [width] wide is at most [columns] of [maxWidth], [gap] apart, and stands
  /// in the middle.
  static EdgeInsets widen(
    EdgeInsets padding,
    double width, {
    int columns = 1,
    double gap = 0,
  }) {
    final content = columns * maxWidth + (columns - 1) * gap;
    final extra = (width - padding.horizontal - content) / 2;
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

/// Like [ContentWidth], for a page of cards that stand in columns on a wide
/// screen (DESIGN.md EL3): it also tells the builder how many columns the
/// width holds, and keeps each of them at most [ContentWidth.maxWidth].
class ContentColumns extends StatelessWidget {
  const ContentColumns({
    super.key,
    this.padding = EdgeInsets.zero,
    this.gap = 0,
    required this.builder,
  });

  /// The padding on a phone.
  final EdgeInsets padding;

  /// Between two columns.
  final double gap;

  /// Builds the scroll view with the padding and the number of columns for
  /// the width it is given.
  final Widget Function(BuildContext context, EdgeInsets padding, int columns)
  builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = ContentWidth.columnsFor(width);
        return builder(
          context,
          ContentWidth.widen(padding, width, columns: columns, gap: gap),
          columns,
        );
      },
    );
  }
}
