import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:miserend/theme/miserend_theme.dart';
import 'package:miserend/theme/tokens.dart';

/// One block of the church details page and the Névjegy page.
///
/// The page used to alternate hand-rolled `Colors.black12` bands with bare
/// `Card`s, which is why no two sections lined up. Every section now goes
/// through here instead, so adding one does not mean re-deciding the padding.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    required this.child,
    this.trailing,
    this.bleed = EdgeInsets.zero,
  });

  /// Around a card standing straight on a page: the screen edge's distance to
  /// the sides, and the theme's half gap above and below (DESIGN.md TK2).
  static const EdgeInsets margin = EdgeInsets.symmetric(
    horizontal: Spacing.l,
    vertical: Spacing.xs,
  );

  final String? title;
  final Widget child;

  /// Sits on the title's row, for a section that carries an action.
  final Widget? trailing;

  /// How far [child] reaches out of the card's inner padding, for content
  /// whose tap areas are larger than what is seen of it: what is seen stays
  /// where any content stands, the tap areas reach into the padding, and over
  /// the title from below. The reach takes nothing tappable from the title,
  /// whose text is not.
  final EdgeInsets bleed;

  @override
  Widget build(BuildContext context) {
    assert(
      bleed.left <= Spacing.l &&
          bleed.top <= Spacing.l &&
          bleed.right <= Spacing.l &&
          bleed.bottom <= Spacing.l,
      "the content can reach no further than the card's edge",
    );
    final title = this.title;
    return Card(
      margin: margin,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Spacing.l - bleed.left,
          title == null ? Spacing.l - bleed.top : Spacing.l,
          Spacing.l - bleed.right,
          Spacing.l - bleed.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Padding(
                padding: EdgeInsets.only(left: bleed.left, right: bleed.right),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.sectionTitle,
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
              ),
              const SizedBox(height: Spacing.s),
              _OverlapAbove(by: bleed.top, child: child),
            ] else
              child,
          ],
        ),
      ),
    );
  }
}

/// Lays [child] out [by] higher than where it stands, overlapping what is
/// above it by that much, and takes taps there too: a hit test that checks
/// its own box would leave the overlap dead.
class _OverlapAbove extends SingleChildRenderObjectWidget {
  const _OverlapAbove({required this.by, required super.child});

  final double by;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderOverlapAbove(by);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderOverlapAbove renderObject,
  ) {
    renderObject.by = by;
  }
}

class _RenderOverlapAbove extends RenderShiftedBox {
  _RenderOverlapAbove(this._by) : super(null);

  double _by;

  set by(double value) {
    if (value == _by) return;
    _by = value;
    markNeedsLayout();
  }

  Size _overlapped(Size childSize, BoxConstraints constraints) =>
      constraints.constrain(
        Size(
          childSize.width,
          (childSize.height - _by).clamp(0, double.infinity),
        ),
      );

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    return _overlapped(child.getDryLayout(constraints), constraints);
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      (super.computeMinIntrinsicHeight(width) - _by).clamp(0, double.infinity);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      (super.computeMaxIntrinsicHeight(width) - _by).clamp(0, double.infinity);

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(constraints, parentUsesSize: true);
    (child.parentData! as BoxParentData).offset = Offset(0, -_by);
    size = _overlapped(child.size, constraints);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      hitTestChildren(result, position: position);
}
