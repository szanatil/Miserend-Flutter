import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:miserend/extentions.dart';
import 'package:miserend/theme/miserend_colors.dart';
import 'package:miserend/theme/tokens.dart';

/// The time of a mass, in the orange that marks a time and nothing else
/// (DESIGN.md KO3, SZ4). It stays in a container of its own: orange text on a
/// surface would not be legible.
class TimeChip extends StatelessWidget {
  const TimeChip({
    super.key,
    required this.time,
    this.onTap,
    this.hasInfo = false,
    this.ongoing = false,
  }) : _label = null;

  /// Stands in for the masses a row has no room for. It opens nothing of its
  /// own: whatever the row sits on leads to where every mass is listed.
  const TimeChip.more({super.key})
    : time = null,
      onTap = null,
      hasInfo = false,
      ongoing = false,
      _label = moreLabel;

  /// The text of [TimeChip.more].
  static const String moreLabel = '…';

  static const EdgeInsets _padding = EdgeInsets.symmetric(
    horizontal: Spacing.s,
    vertical: Spacing.xs,
  );

  static const ShapeBorder _shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(Radii.s)),
  );

  final TimeOfDay? time;

  final String? _label;

  /// Only set where there is something to open; most masses carry nothing but
  /// the generic "Római katolikus Szentmise", and a chip that opens an empty
  /// popup teaches people not to tap the ones that matter.
  final VoidCallback? onTap;

  /// Draws the marker that says this chip has more behind it.
  final bool hasInfo;

  /// The mass is going on now (CONTEXT.md, „Épp most tartó mise"): the chip
  /// turns the filled orange.
  final bool ongoing;

  /// The width a chip takes for [label], so that a row can fit chips by width
  /// before laying them out. A [tappable] one has the (i) marker and takes
  /// taps on at least [kMinInteractiveDimension].
  static double widthOf(
    BuildContext context,
    String label, {
    bool tappable = false,
  }) {
    final width = _sizeOf(context, label).width;
    if (!tappable) return width;
    return math.max(
      width + Spacing.s + IconSizes.small,
      kMinInteractiveDimension,
    );
  }

  /// The height a tappable chip takes, its tap target included.
  static double tappableHeightOf(BuildContext context) =>
      math.max(heightOf(context), kMinInteractiveDimension);

  /// The height a chip without the (i) marker and a tap target takes —
  /// whatever its label, all on one line — so that a row of them keeps its
  /// line with no chip in it.
  static double heightOf(BuildContext context) =>
      _sizeOf(context, moreLabel).height;

  static Size _sizeOf(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: _textStyle(context)),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final size = Size(
      painter.width + _padding.horizontal,
      painter.height + _padding.vertical,
    );
    painter.dispose();
    return size;
  }

  /// As strong as the church name beside it and bolder, so that the time
  /// leads the card (TI3); the figures line up from chip to chip (TI4).
  static TextStyle? _textStyle(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = Theme.of(
      context,
    ).extension<MiserendColors>()!.occasionTimeColors(ongoing: ongoing);

    final label = Text(
      _label ?? time?.to24hours() ?? '?',
      style: _textStyle(context)?.copyWith(color: foreground),
    );
    final content = Padding(
      padding: _padding,
      child:
          hasInfo
              ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  label,
                  const SizedBox(width: Spacing.s),
                  // A chip's icon size (IK3).
                  IconTheme.merge(
                    data: const IconThemeData(size: IconSizes.small),
                    child: Icon(Icons.info_outline_rounded, color: foreground),
                  ),
                ],
              )
              : label,
    );

    final onTap = this.onTap;
    // A chip that opens nothing gives no touch feedback (KO4).
    if (onTap == null) return _surface(background, content);
    // Read out as one button, as large as the area it takes taps in.
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: _TapTarget(
          child: _surface(background, InkWell(onTap: onTap, child: content)),
        ),
      ),
    );
  }

  Widget _surface(Color background, Widget child) => Material(
    color: background,
    shape: _shape,
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

/// Takes taps on at least 48 × 48 around a chip drawn smaller (DESIGN.md
/// AM3), as Material pads its buttons: the chip stays centred at its own size,
/// and a tap in the room around it lands on the chip.
class _TapTarget extends SingleChildRenderObjectWidget {
  const _TapTarget({required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderTapTarget();
}

class _RenderTapTarget extends RenderShiftedBox {
  _RenderTapTarget() : super(null);

  static const double _min = kMinInteractiveDimension;

  @override
  double computeMinIntrinsicWidth(double height) =>
      math.max(super.computeMinIntrinsicWidth(height), _min);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      math.max(super.computeMaxIntrinsicWidth(height), _min);

  @override
  double computeMinIntrinsicHeight(double width) =>
      math.max(super.computeMinIntrinsicHeight(width), _min);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      math.max(super.computeMaxIntrinsicHeight(width), _min);

  Size _grown(Size chip, BoxConstraints constraints) => constraints.constrain(
    Size(math.max(chip.width, _min), math.max(chip.height, _min)),
  );

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _grown(child!.getDryLayout(constraints), constraints);

  @override
  void performLayout() {
    final child = this.child!;
    child.layout(constraints, parentUsesSize: true);
    size = _grown(child.size, constraints);
    (child.parentData! as BoxParentData).offset = Alignment.center.alongOffset(
      size - child.size as Offset,
    );
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (super.hitTest(result, position: position)) return true;
    if (!size.contains(position)) return false;
    final centre = child!.size.center(Offset.zero);
    return result.addWithRawTransform(
      transform: MatrixUtils.forceToPoint(centre),
      position: centre,
      hitTest: (result, position) => child!.hitTest(result, position: centre),
    );
  }
}
