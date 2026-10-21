import 'package:flutter/material.dart';
import 'package:miserend/theme/tokens.dart';

/// A long text field that shows a few lines and expands in place.
///
/// The descriptions are long enough to need this — church 38's `leiras` runs to
/// 9772 characters — but most fields are a line or two, so the tile only grows
/// a "Tovább" control when the text actually overflows [previewLines].
class ExpandableInfoTile extends StatefulWidget {
  const ExpandableInfoTile({
    super.key,
    this.title,
    required this.text,
    this.previewLines = 3,
    this.style,
  });

  /// Already run through `MiserendText.normalize`.
  final String text;

  /// Omitted where the surrounding section already names the field.
  final String? title;

  final int previewLines;
  final TextStyle? style;

  @override
  State<ExpandableInfoTile> createState() => _ExpandableInfoTileState();
}

class _ExpandableInfoTileState extends State<ExpandableInfoTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style =
        widget.style ??
        Theme.of(context).textTheme.bodyMedium ??
        const TextStyle();
    final title = widget.title;

    return LayoutBuilder(
      builder: (context, constraints) {
        final overflows = _overflows(constraints.maxWidth, style);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: Spacing.s),
            ],
            Text(
              widget.text,
              style: style,
              maxLines: _expanded || !overflows ? null : widget.previewLines,
              overflow:
                  _expanded || !overflows
                      ? TextOverflow.clip
                      : TextOverflow.ellipsis,
            ),
            if (overflows)
              Align(
                alignment: Alignment.centerLeft,
                // The arrow carries the meaning — it says which way the block
                // is about to move — so it stays in both states rather than
                // only marking the collapsed one.
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
                    minimumSize: Size.zero,
                    // Drawn this small, it still takes taps on 48 (AM3).
                    tapTargetSize: MaterialTapTargetSize.padded,
                  ),
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                  ),
                  label: Text(_expanded ? 'Kevesebb' : 'Több'),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Whether the text needs more than [ExpandableInfoTile.previewLines] at this
  /// width. Measured rather than guessed from the character count, because the
  /// fields carry their own line breaks.
  bool _overflows(double maxWidth, TextStyle style) {
    if (!maxWidth.isFinite) {
      return false;
    }
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: style),
      maxLines: widget.previewLines,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: maxWidth);
    final exceeded = painter.didExceedMaxLines;
    painter.dispose();
    return exceeded;
  }
}
