import 'package:flutter/material.dart';

/// Takes the room of [placeholder] or of [child], whichever is larger, whatever
/// [child] says. The cards use it so that what stands below a short text
/// stands at the same height on every card. The placeholder is laid out
/// invisibly, so it follows the font and the text size of the card.
class ReservedRoom extends StatelessWidget {
  const ReservedRoom({
    super.key,
    required this.placeholder,
    required this.child,
  });

  /// Reserves [lines] lines of [style], an empty run of line breaks: room with
  /// no text of its own for a test or a screen reader to find.
  ReservedRoom.lines({
    super.key,
    required int lines,
    required TextStyle? style,
    required this.child,
  }) : placeholder = Text('\n' * (lines - 1), style: style);

  final Widget placeholder;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ExcludeSemantics(
          child: Visibility(
            visible: false,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: placeholder,
          ),
        ),
        child,
      ],
    );
  }
}
