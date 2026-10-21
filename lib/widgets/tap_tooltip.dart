import 'package:flutter/material.dart';
import 'package:miserend/theme/tokens.dart';

/// A tooltip that a tap opens over a small element: a cut-off chip's whole
/// text, or a liturgical language's name over its flag (DESIGN.md KO21).
///
/// It stands [Spacing.xs] off the element's visible edge, above it, and below
/// only if there is no room above. It stays until another touch or a scroll,
/// for at most [Tooltips.chipShowDuration]; a tap on the same element starts
/// that time again. No ripple or highlight shows that it is there.
///
/// It adds nothing for a screen reader: the element reads the same text
/// already (AM5).
class TapTooltip extends StatelessWidget {
  const TapTooltip({
    super.key,
    required this.message,
    this.visibleHeight,
    required this.child,
  });

  final String message;

  /// The height of what is seen of [child], standing in its middle, when the
  /// child is a larger tap area around it; the child's own height if null.
  final double? visibleHeight;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      triggerMode: TooltipTriggerMode.tap,
      preferBelow: false,
      showDuration: Tooltips.chipShowDuration,
      positionDelegate: _offVisibleEdge,
      excludeFromSemantics: true,
      child: child,
    );
  }

  Offset _offVisibleEdge(TooltipPositionContext context) =>
      positionDependentBox(
        size: context.overlaySize,
        childSize: context.tooltipSize,
        target: context.target,
        verticalOffset:
            (visibleHeight ?? context.targetSize.height) / 2 + Spacing.xs,
        preferBelow: context.preferBelow,
      );
}
