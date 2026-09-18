import 'dart:async';

import 'package:flutter/material.dart';

/// „8 / 42 találat" at the bottom of the results while they scroll: how far
/// the user has got, out of how many (spec 0010, „Darabszám-jelvény"). It
/// fades out a little after the scrolling stops, so that it does not cover
/// the cards for good.
class ResultCountBadge extends StatefulWidget {
  const ResultCountBadge({
    super.key,
    required this.controller,
    required this.rowExtent,
    required this.topPadding,
    required this.shown,
    required this.found,
    required this.foundIsFinal,
  });

  /// How long the badge stays after the last movement.
  static const Duration lingerFor = Duration(milliseconds: 1500);

  /// The results' scrolling, which the badge follows.
  final ScrollController controller;

  /// The height of one card, and the space above the first.
  final double rowExtent;
  final double topPadding;

  /// The cards in the list.
  final int shown;

  /// The churches found; with [foundIsFinal] false, only so far, and the
  /// badge says so with a „+".
  final int found;
  final bool foundIsFinal;

  @override
  State<ResultCountBadge> createState() => _ResultCountBadgeState();
}

class _ResultCountBadgeState extends State<ResultCountBadge> {
  bool _visible = false;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_scrolled);
  }

  @override
  void didUpdateWidget(ResultCountBadge oldWidget) {
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
    _hide = Timer(ResultCountBadge.lingerFor, () {
      if (mounted) setState(() => _visible = false);
    });
    setState(() => _visible = true);
  }

  /// The number of the last card seen whole.
  int _lastSeen() {
    if (!widget.controller.hasClients) return 0;
    final position = widget.controller.position;
    // Not laid out yet on the list's first frame.
    if (!position.hasContentDimensions || !position.hasViewportDimension) {
      return 0;
    }
    final bottom =
        position.pixels + position.viewportDimension - widget.topPadding;
    return (bottom / widget.rowExtent).floor().clamp(0, widget.shown);
  }

  @override
  Widget build(BuildContext context) {
    final plus = widget.foundIsFinal ? '' : '+';
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 300),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(160),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              '${_lastSeen()} / ${widget.found}$plus találat',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
