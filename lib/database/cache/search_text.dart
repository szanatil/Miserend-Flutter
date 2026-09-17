/// [text] as the local search compares it: lower case, with the accented
/// letters folded onto their base letter, so that „matyas", „MÁTYÁS" and
/// „Mátyás" are the same (#12). SQLite's `LIKE` and `NOCASE` fold ASCII only,
/// hence the fold happens here, once when a row is written.
///
/// The Hungarian long vowels fold like the short ones (ő, ö → o), and so do
/// the letters of the languages whose churches miserend.hu lists: Slovak,
/// Czech, Romanian, Croatian, Serbian, Slovenian, Polish, German. Other
/// scripts are only lower-cased.
String searchText(String text) {
  final lower = text.toLowerCase();
  final folded = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    folded.write(_folds[char] ?? char);
  }
  return folded.toString();
}

const Map<String, String> _folds = {
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ä': 'a',
  'ă': 'a',
  'ą': 'a',
  'ã': 'a',
  'ć': 'c',
  'č': 'c',
  'ç': 'c',
  'ď': 'd',
  'đ': 'd',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'ě': 'e',
  'ę': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ĺ': 'l',
  'ľ': 'l',
  'ł': 'l',
  'ń': 'n',
  'ň': 'n',
  'ñ': 'n',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'ö': 'o',
  'ő': 'o',
  'õ': 'o',
  'ŕ': 'r',
  'ř': 'r',
  'ś': 's',
  'š': 's',
  'ș': 's',
  'ş': 's',
  'ß': 'ss',
  'ť': 't',
  'ț': 't',
  'ţ': 't',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ű': 'u',
  'ů': 'u',
  'ũ': 'u',
  'ý': 'y',
  'ÿ': 'y',
  'ź': 'z',
  'ż': 'z',
  'ž': 'z',
};
