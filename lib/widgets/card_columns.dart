import 'dart:math';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:miserend/theme/tokens.dart';

/// One row of a list's cards on a wide screen (DESIGN.md EL3): [columns]
/// equal slots [gap] apart, every card as tall as the tallest, so that the
/// rows read as a grid.
///
/// A short last row leaves its empty slots empty rather than widening its
/// cards. The cards are measured, then laid out again at the row's height:
/// an [IntrinsicHeight] would do the same, but a card's [LayoutBuilder]
/// cannot answer it.
class CardRow extends MultiChildRenderObjectWidget {
  const CardRow({
    super.key,
    required this.columns,
    required this.gap,
    required super.children,
  }) : assert(children.length <= columns);

  /// The gap between a list's cards, across as well as down (DESIGN.md TK2).
  static const double listGap = Spacing.s;

  final int columns;
  final double gap;

  /// [cards] as a list's row of [columns], [listGap] apart; in one column,
  /// the card itself, as before there were columns.
  static Widget of(int columns, List<Widget> cards) =>
      columns == 1
          ? cards.single
          : CardRow(columns: columns, gap: listGap, children: cards);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderCardRow(columns: columns, gap: gap);

  @override
  void updateRenderObject(BuildContext context, RenderCardRow renderObject) {
    renderObject
      ..columns = columns
      ..gap = gap;
  }
}

/// Columns of cards side by side on a wide screen, each from the top
/// (DESIGN.md EL3), with an optional [tail] under whichever is shorter — the
/// first, if they are as tall.
class CardColumns extends MultiChildRenderObjectWidget {
  CardColumns({
    super.key,
    required this.gap,
    required List<Widget> columns,
    Widget? tail,
  }) : hasTail = tail != null,
       assert(columns.isNotEmpty),
       super(children: [...columns, if (tail != null) tail]);

  /// Between two columns. Negative where the cards bring side margins of
  /// their own, wider than the gap is to be: the columns then overlap in
  /// those margins.
  final double gap;

  /// Whether the last child is the tail rather than a column.
  final bool hasTail;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderCardColumns(gap: gap, hasTail: hasTail);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderCardColumns renderObject,
  ) {
    renderObject
      ..gap = gap
      ..hasTail = hasTail;
  }
}

class _CardParentData extends ContainerBoxParentData<RenderBox> {}

abstract class _RenderCards extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _CardParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _CardParentData> {
  _RenderCards({required double gap}) : _gap = gap;

  double get gap => _gap;
  double _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  /// Each of [count] columns' width in the width the parent gives.
  double columnWidth(int count) =>
      (constraints.maxWidth - gap * (count - 1)) / count;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _CardParentData) {
      child.parentData = _CardParentData();
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

/// Lays out a [CardRow].
class RenderCardRow extends _RenderCards {
  RenderCardRow({required int columns, required super.gap})
    : _columns = columns;

  int get columns => _columns;
  int _columns;
  set columns(int value) {
    if (value == _columns) return;
    _columns = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final width = columnWidth(columns);
    final cards = getChildrenAsList();

    var tallest = 0.0;
    for (final card in cards) {
      card.layout(
        BoxConstraints(minWidth: width, maxWidth: width),
        parentUsesSize: true,
      );
      tallest = max(tallest, card.size.height);
    }
    for (final (index, card) in cards.indexed) {
      card.layout(BoxConstraints.tightFor(width: width, height: tallest));
      (card.parentData! as _CardParentData).offset = Offset(
        index * (width + gap),
        0,
      );
    }
    size = constraints.constrain(Size(constraints.maxWidth, tallest));
  }
}

/// Lays out a [CardColumns].
class RenderCardColumns extends _RenderCards {
  RenderCardColumns({required super.gap, required bool hasTail})
    : _hasTail = hasTail;

  bool get hasTail => _hasTail;
  bool _hasTail;
  set hasTail(bool value) {
    if (value == _hasTail) return;
    _hasTail = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final children = getChildrenAsList();
    final columns =
        hasTail ? children.sublist(0, children.length - 1) : children;
    final width = columnWidth(columns.length);
    final loose = BoxConstraints(minWidth: width, maxWidth: width);

    final heights = <double>[];
    for (final (index, column) in columns.indexed) {
      column.layout(loose, parentUsesSize: true);
      (column.parentData! as _CardParentData).offset = Offset(
        index * (width + gap),
        0,
      );
      heights.add(column.size.height);
    }
    if (hasTail) {
      final tail = children.last;
      final shorter = heights.indexOf(heights.reduce(min));
      tail.layout(loose, parentUsesSize: true);
      (tail.parentData! as _CardParentData).offset = Offset(
        shorter * (width + gap),
        heights[shorter],
      );
      heights[shorter] += tail.size.height;
    }
    size = constraints.constrain(
      Size(constraints.maxWidth, heights.reduce(max)),
    );
  }
}
