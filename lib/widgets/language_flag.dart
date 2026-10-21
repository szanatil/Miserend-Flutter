import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:miserend/theme/tokens.dart';

/// The Hungarian name of each `nyelvek` code with a flag in `assets/flags/`
/// — the language it marks, not the country whose flag is borrowed
/// (CONTEXT.md, „Liturgikus nyelv jelölése"). A code outside this map has no
/// asset, so membership doubles as "is there a flag for it".
const Map<String, String> languageNames = {
  'cu': 'ószláv',
  'de': 'német',
  'en': 'angol',
  'es': 'spanyol',
  'fr': 'francia',
  'gr': 'görög',
  'hr': 'horvát',
  'hu': 'magyar',
  'it': 'olasz',
  'pl': 'lengyel',
  'pt': 'portugál',
  'ro': 'román',
  'ru': 'orosz',
  'rue': 'ruszin',
  'si': 'szlovén',
  'sk': 'szlovák',
  'tl': 'tagalog',
  'ua': 'ukrán',
  'va': 'latin',
};

/// [code]'s Hungarian name, or the code itself when it has none.
String languageName(String code) => languageNames[code] ?? code;

/// The flag of a liturgical language, read out by its Hungarian name. An
/// unrecognised code has no asset, and shows as text instead: that keeps the
/// fact that the church serves in some further language, rather than dropping
/// it silently.
class LanguageFlag extends StatelessWidget {
  const LanguageFlag(this.code, {super.key});

  final String code;

  /// The size a flag is drawn at.
  static const double width = 24;
  static const double height = 18;

  @override
  Widget build(BuildContext context) {
    final name = languageNames[code];
    if (name == null) {
      return Chip(
        label: Text(code.toUpperCase()),
        visualDensity: VisualDensity.compact,
      );
    }

    return Semantics(
      label: name,
      image: true,
      child: Container(
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          // Several of these flags run to white at the edge — the English one
          // is white with a red cross — and would otherwise bleed into the
          // card behind them.
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(Radii.xs),
        ),
        child: SvgPicture.asset('assets/flags/$code.svg', fit: BoxFit.contain),
      ),
    );
  }
}
