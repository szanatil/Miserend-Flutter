import 'package:html_unescape/html_unescape.dart';

/// Turns the API's free-text fields into something a [Text] widget can show.
///
/// `leiras`, `plebania`, `miserend_megjegyzes` and `megkozelites` are not HTML
/// documents but they are not plain text either: they are entity-encoded
/// (`&eacute;`, `&nbsp;`), carry the occasional `<br />`, and use `\r\n` line
/// endings. Worse, they pad with lines that hold nothing but `&nbsp;` — the
/// description of church 38 opens with seven of them in a row, which renders as
/// a screen-tall hole above the first sentence.
class MiserendText {
  static final HtmlUnescape _unescape = HtmlUnescape();

  static final RegExp _lineBreakTag = RegExp(
    r'<br\s*/?>',
    caseSensitive: false,
  );

  /// Anything else that looks like a tag. The live data only ever carries
  /// `<br>`, but a stray `<p>` would otherwise be shown to the user verbatim.
  static final RegExp _anyTag = RegExp(r'</?[a-zA-Z][^>]*>');

  /// Two or more blank lines in a row, which is always padding rather than
  /// intent in this data.
  static final RegExp _blankRun = RegExp(r'\n{3,}');

  /// Empty string when there is nothing to show, so callers can test the
  /// result rather than testing the raw field.
  static String normalize(String? raw) {
    if (raw == null || raw.isEmpty) {
      return '';
    }

    // Tags first, entities second: unescaping first would turn a literal
    // `&lt;br&gt;` into markup and then strip it, losing real text.
    var text = raw.replaceAll(_lineBreakTag, '\n').replaceAll(_anyTag, '');
    text = _unescape.convert(text);

    text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    // A non-breaking space is padding here, not a character worth keeping.
    text = text.replaceAll('\u00A0', ' ');

    text = text.split('\n').map((line) => line.trim()).join('\n');
    text = text.replaceAll(_blankRun, '\n\n');

    return text.trim();
  }

  /// True when the field holds nothing worth giving a section to.
  static bool isEmpty(String? raw) => normalize(raw).isEmpty;
}
