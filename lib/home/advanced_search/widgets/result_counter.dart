import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:miserend/theme/tokens.dart';

/// „8 / 42 találat" at the bottom of the results while they scroll: how far
/// the user has got, out of how many (spec 0010, „Darabszám-számláló";
/// DESIGN.md KO20). It fades out a little after the scrolling stops, so that
/// it does not cover the cards for good. Not a badge: it marks no state.
class ResultCounter extends StatefulWidget {
  const ResultCounter({
    super.key,
    required this.controller,
    required this.list,
    required this.shown,
    required this.found,
    required this.foundIsFinal,
  });

  /// How long the counter stays after the last movement.
  static const Duration lingerFor = Duration(milliseconds: 1500);

  /// The results' scrolling, which the counter follows.
  final ScrollController controller;

  /// The key of the sliver list holding the cards. The cards are as tall as
  /// their content (DESIGN.md EL2), so the count reads where each one ends
  /// off the list itself.
  final GlobalKey list;

  /// The cards in the list.
  final int shown;

  /// The churches found; with [foundIsFinal] false, only so far, and the
  /// counter says so with a „+".
  final int found;
  final bool foundIsFinal;

  @override
  State<ResultCounter> createState() => _ResultCounterState();
}

class _ResultCounterState extends State<ResultCounter> {
  bool _visible = false;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_scrolled);
  }

  @override
  void didUpdateWidget(ResultCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_scrolled);
      widget.controller.addListener(_scrolled);
    }
  }

  @override
  void dispose() {
    _hide?.cancel();
    widget.controller.removeListener(_scrolled);
    super.dispose();
  }

  void _scrolled() {
    _hide?.cancel();
    _hide = Timer(ResultCounter.lingerFor, () {
      if (mounted) setState(() => _visible = false);
    });
    setState(() => _visible = true);
    // The cards are only where this scroll puts them once laid out.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final lastSeen = _lastSeen();
      if (lastSeen != _shownLastSeen) {
        setState(() => _shownLastSeen = lastSeen);
      }
    });
  }

  /// The number in front, as of the last layout.
  int _shownLastSeen = 0;

  /// The number of the last card seen whole: the cards scrolled past and
  /// those whose bottom is on the screen.
  int _lastSeen() {
    final list = widget.list.currentContext?.findRenderObject();
    if (list is! RenderSliverMultiBoxAdaptor) return 0;
    final constraints = list.constraints;
    final visibleEnd =
        constraints.scrollOffset + constraints.remainingPaintExtent;
    var child = list.firstChild;
    if (child == null) return 0;
    // The cards above the first one laid out are all scrolled past.
    var seen = list.indexOf(child);
    while (child != null) {
      if (list.childScrollOffset(child)! + child.size.height > visibleEnd) {
        break;
      }
      seen = list.indexOf(child) + 1;
      child = list.childAfter(child);
    }
    return seen.clamp(0, widget.shown);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final plus = widget.foundIsFinal ? '' : '+';
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 300),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: scheme.inverseSurface,
            shape: Radii.full,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.l,
              vertical: Spacing.s,
            ),
            child: Text(
              '$_shownLastSeen / ${widget.found}$plus találat',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onInverseSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
