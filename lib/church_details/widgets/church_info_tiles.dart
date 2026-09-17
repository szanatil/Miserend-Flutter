import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:miserend/colors.dart';
import 'package:miserend/database/cache/community.dart';
import 'package:miserend/widgets/launch_external.dart';
import 'package:miserend/widgets/section_card.dart';

/// Wheelchair access, stated either way.
///
/// Unlike confession, a "no" here is real, checked information and worth
/// showing: someone planning a visit needs it more than they need the yes.
class AccessibilityTile extends StatelessWidget {
  const AccessibilityTile({super.key, required this.accessibility});

  final Map<String, dynamic> accessibility;

  static const Map<String, String> _wheelchair = {
    'yes': 'Kerekesszékkel megközelíthető',
    'no': 'Kerekesszékkel nem megközelíthető',
    'limited': 'Kerekesszékkel részben megközelíthető',
  };

  /// Only the wheelchair keys are rendered. The field is an open OSM-style map,
  /// and printing an unrecognised `key: value` raw would be worse than leaving
  /// it out.
  static bool hasContent(Map<String, dynamic>? accessibility) =>
      accessibility != null &&
      _wheelchair.containsKey(_value(accessibility, 'wheelchair'));

  static String _value(Map<String, dynamic> map, String key) =>
      (map[key] as Object?)?.toString().trim().toLowerCase() ?? '';

  @override
  Widget build(BuildContext context) {
    final state = _value(accessibility, 'wheelchair');
    final description =
        (accessibility['wheelchair:description'] as Object?)
            ?.toString()
            .trim() ??
        '';

    return SectionCard(
      title: 'Akadálymentesség',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            state == 'no' ? Icons.not_accessible : Icons.accessible,
            size: 20,
            color: Colors.black54,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_wheelchair[state] ?? ''),
                if (description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      description,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.apply(color: Colors.black54),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The liturgical languages the church generally serves in, drawn as flags.
///
/// This is a church-level field, not a per-mass one — the v4 API carries no
/// language on the individual mass, so no flag here says anything about which
/// mass is held in which language.
///
/// The `nyelvek` codes are miserend.hu's own closed vocabulary, neither ISO 639
/// nor ISO 3166: `va` (Vatican) stands for Latin, `cu` for Church Slavonic and
/// `rue` for Rusyn, none of which is a country. Reading them as ISO 639 is a
/// mistake that has already been made here — it left real churches showing
/// "VA" and "TL" as text.
class LanguagesTile extends StatelessWidget {
  const LanguagesTile({super.key, required this.languages});

  final List<String> languages;

  /// Every code with a flag in `assets/flags/`, mapped to the language it
  /// marks — not to the country whose flag is borrowed. A code outside this
  /// map has no asset, so membership doubles as "is there a flag for it".
  static const Map<String, String> _names = {
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

  /// A Hungarian-only church in Hungary tells the reader nothing — 395 of 435
  /// sampled churches are exactly that — so the tile only appears where there
  /// is something unexpected to say.
  static bool hasContent(List<String> languages) {
    final codes = _clean(languages);
    return codes.isNotEmpty && !(codes.length == 1 && codes.first == 'hu');
  }

  static List<String> _clean(List<String> languages) =>
      languages
          .map((code) => code.trim().toLowerCase())
          .where((code) => code.isNotEmpty)
          .toList();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Nyelvek',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final code in _clean(languages)) _flag(code)],
      ),
    );
  }

  Widget _flag(String code) {
    final name = _names[code];
    if (name == null) {
      // An unrecognised code has no asset. Showing it as text keeps the fact
      // that the church serves in some further language, rather than dropping
      // it silently.
      return Chip(
        label: Text(code.toUpperCase()),
        visualDensity: VisualDensity.compact,
      );
    }

    return Semantics(
      label: name,
      image: true,
      child: Container(
        width: 24,
        height: 18,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          // Several of these flags run to white at the edge — the English one
          // is white with a red cross — and would otherwise bleed into the
          // card behind them.
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(2),
        ),
        child: SvgPicture.asset('assets/flags/$code.svg', fit: BoxFit.contain),
      ),
    );
  }
}

/// Communities attached to the church, each with its own page.
class CommunitiesTile extends StatelessWidget {
  const CommunitiesTile({super.key, required this.communities});

  final List<Community> communities;

  static bool hasContent(List<Community> communities) =>
      communities.any((c) => (c.name ?? '').trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Közösségek',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final community in communities)
            if ((community.name ?? '').trim().isNotEmpty)
              _row(context, community),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, Community community) {
    final link = community.link?.trim() ?? '';
    final name = community.name!.trim();
    if (link.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(name),
      );
    }
    return InkWell(
      onTap: () {
        final uri = Uri.tryParse(link);
        if (uri != null) {
          launchExternal(context, uri);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          name,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.apply(color: CustomColors.accent),
        ),
      ),
    );
  }
}
