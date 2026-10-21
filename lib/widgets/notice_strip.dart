import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.l,
          vertical: Spacing.s,
        ),
        child: _StripLayout(
          children: [
            Row(
              children: [
                IconTheme.merge(
                  data: const IconThemeData(size: IconSizes.small),
                  child: Icon(icon, color: iconColor),
                ),
                const SizedBox(width: Spacing.s),
                Expanded(
                  child: Text(
                    text,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: textColor),
                  ),
                ),
              ],
            ),
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }
}

/// Lays the line and the buttons side by side while the buttons take at most
/// half the width, and the buttons under the line, at the end, once they
/// would take more: beside them a large text would have no room (KO7, EL2).
class _StripLayout extends MultiChildRenderObjectWidget {
  const _StripLayout({required super.children});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderStripLayout();
}

class _StripParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderStripLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _StripParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _StripParentData> {
  RenderBox get _line => firstChild!;
  RenderBox get _buttons => lastChild!;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _StripParentData) {
      child.parentData = _StripParentData();
    }
  }

  bool _stacks(double width) =>
      _buttons.getMaxIntrinsicWidth(double.infinity) > width / 2;

  /// Lays out with [layoutChild] and gives the size, placing the children
  /// only if [place].
  Size _layout(
    BoxConstraints constraints,
    Size Function(RenderBox, BoxConstraints) layoutChild, {
    required bool place,
  }) {
    assert(constraints.hasBoundedWidth, 'A strip is as wide as its parent.');
    final width = constraints.maxWidth;
    final buttons = layoutChild(_buttons, BoxConstraints(maxWidth: width));
    if (_stacks(width)) {
      final line = layoutChild(_line, BoxConstraints.tightFor(width: width));
      if (place) {
        _offset(_line, Offset.zero);
        _offset(_buttons, Offset(width - buttons.width, line.height));
      }
      return constraints.constrain(Size(width, line.height + buttons.height));
    }
    final line = layoutChild(
      _line,
      BoxConstraints.tightFor(width: width - buttons.width),
    );
    final height = math.max(line.height, buttons.height);
    if (place) {
      _offset(_line, Offset(0, (height - line.height) / 2));
      _offset(
        _buttons,
        Offset(width - buttons.width, (height - buttons.height) / 2),
      );
    }
    return constraints.constrain(Size(width, height));
  }

  void _offset(RenderBox child, Offset offset) =>
      (child.parentData! as _StripParentData).offset = offset;

  @override
  void performLayout() {
    size = _layout(constraints, (child, constraints) {
      child.layout(constraints, parentUsesSize: true);
      return child.size;
    }, place: true);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _layout(constraints, ChildLayoutHelper.dryLayoutChild, place: false);

  @override
  double computeMinIntrinsicWidth(double height) => math.max(
    _line.getMinIntrinsicWidth(height),
    _buttons.getMinIntrinsicWidth(height),
  );

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _line.getMaxIntrinsicWidth(height) +
      _buttons.getMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) {
    // With no width to fit in, nothing has to go under the line.
    if (!width.isFinite) {
      return math.max(
        _line.getMinIntrinsicHeight(width),
        _buttons.getMinIntrinsicHeight(width),
      );
    }
    return _layout(
      BoxConstraints(maxWidth: width),
      ChildLayoutHelper.dryLayoutChild,
      place: false,
    ).height;
  }

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}
