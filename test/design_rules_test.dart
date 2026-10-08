import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The mechanical half of DESIGN.md (EH2): raw design values outside
/// `lib/theme/` (TO1) and non-rounded icons (IK1). The other rules are left
/// to the review.
final Map<String, RegExp> _rules = {
  'color': RegExp(
    r'\bColors\.(?!transparent\b)[a-zA-Z]|\bColor\(0x|\bColor\.fromARGB|\bCustomColors\.|\.withAlpha\(|\.withOpacity\(|\.primaryColor\b',
  ),
  'fontSize': RegExp(r'\bfontSize\s*:'),
  'radius': RegExp(r'\b(BorderRadius|Radius)\.circular\(\s*\d'),
  'spacing': RegExp(
    r'\bEdgeInsets\.\w+\([^)]*\b(?!0\b)\d+(\.\d+)?\b|\bSizedBox\(\s*(height|width)\s*:\s*(?!0\b)\d',
  ),
  'elevation': RegExp(r'\belevation\s*:\s*(?!0\b)\d'),
  'icon': RegExp(r'\bIcons\.(?![a-z_]+_rounded\b)[a-z_]+'),
};

/// The known deviations found by the design audit of 2026-10-07, as the
/// number of offending lines per file and rule, each with the issue that
/// removes it. A count may only fall: a new deviation fails the test, and a
/// fixed one fails it too until its entry is lowered or removed, so the list
/// never hides a regression behind a fix.
const Map<String, Map<String, (int, String)>> _knownDeviations = {
  'lib/about/about_page.dart': {
    'color': (7, '#58'),
    'icon': (4, '#61'),
    'radius': (1, '#59'),
    'spacing': (4, '#59'),
  },
  'lib/church_details/church_details_page.dart': {
    'color': (10, '#58'),
    'icon': (3, '#61'),
    'spacing': (17, '#59'),
  },
  'lib/church_details/report_problem_page.dart': {'spacing': (5, '#59')},
  'lib/church_details/widgets/adoration_card.dart': {
    'color': (1, '#58'),
    'spacing': (2, '#59'),
  },
  'lib/church_details/widgets/church_info_tiles.dart': {
    'color': (2, '#58'),
    'icon': (1, '#61'),
    'spacing': (4, '#59'),
  },
  'lib/church_details/widgets/contact_card.dart': {
    'color': (1, '#58'),
    'icon': (2, '#61'),
    'spacing': (3, '#59'),
  },
  'lib/church_details/widgets/expandable_info_tile.dart': {
    'icon': (2, '#61'),
    'spacing': (2, '#59'),
  },
  'lib/church_details/widgets/mass_info.dart': {'spacing': (2, '#59')},
  'lib/church_details/widgets/photo_gallery_page.dart': {'color': (3, '#58')},
  'lib/church_details/widgets/photo_header.dart': {
    'color': (1, '#58'),
    'spacing': (1, '#59'),
  },
  'lib/home/advanced_search/advanced_search_page.dart': {
    'color': (5, '#58'),
    'icon': (7, '#61'),
    'spacing': (12, '#59'),
  },
  'lib/home/advanced_search/widgets/result_count_badge.dart': {
    'color': (2, '#58'),
    'radius': (1, '#59'),
    'spacing': (1, '#59'),
  },
  'lib/home/churches/favorite_churches.dart': {'color': (1, '#58')},
  'lib/home/churches/near_churches_page.dart': {'color': (1, '#58')},
  'lib/home/churches/search_results.dart': {'color': (1, '#58')},
  'lib/home/home.dart': {
    'color': (2, '#58'),
    'icon': (2, '#61'),
    'radius': (2, '#59'),
  },
  'lib/home/map/map_page.dart': {'icon': (1, '#61')},
  'lib/home/map/widgets/position_unavailable_banner.dart': {
    'icon': (2, '#60, #61'),
  },
  'lib/home/masses/near_masses_page.dart': {'color': (1, '#58')},
  'lib/splash.dart': {'spacing': (3, '#59')},
  'lib/widgets/language_flag.dart': {'color': (1, '#58'), 'radius': (1, '#59')},
  'lib/widgets/list_status_view.dart': {'spacing': (2, '#59')},
  'lib/widgets/miserend_map.dart': {
    'color': (8, '#58'),
    'fontSize': (2, '#59'),
    'spacing': (2, '#59'),
  },
  'lib/widgets/notice_strip.dart': {'spacing': (2, '#59')},
  'lib/widgets/offline_notice.dart': {'icon': (3, '#61')},
  'lib/widgets/position_unavailable_view.dart': {'spacing': (2, '#59')},
};

/// Counts the lines of each `lib/` file outside `lib/theme/` that match a
/// rule, skipping comment lines.
Map<String, Map<String, int>> _scan() {
  final found = <String, Map<String, int>>{};
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !f.path.startsWith('lib/theme/'));
  for (final file in files) {
    for (final line in file.readAsLinesSync()) {
      if (line.trimLeft().startsWith('//')) continue;
      for (final rule in _rules.entries) {
        if (rule.value.hasMatch(line)) {
          final counts = found.putIfAbsent(file.path, () => {});
          counts[rule.key] = (counts[rule.key] ?? 0) + 1;
        }
      }
    }
  }
  return found;
}

void main() {
  test('lib/ uses design tokens, apart from the listed known deviations', () {
    final found = _scan();
    final problems = <String>[];
    final paths = {...found.keys, ..._knownDeviations.keys}.toList()..sort();
    for (final path in paths) {
      final rules = {...?found[path]?.keys, ...?_knownDeviations[path]?.keys};
      for (final rule in rules) {
        final count = found[path]?[rule] ?? 0;
        final known = _knownDeviations[path]?[rule];
        final allowed = known?.$1 ?? 0;
        if (count > allowed) {
          problems.add(
            '$path: $count "$rule" line(s), $allowed allowed '
            '(DESIGN.md TO1/IK1; new deviations are not allowed)',
          );
        } else if (count < allowed) {
          problems.add(
            '$path: $count "$rule" line(s), the list still allows $allowed '
            '(${known!.$2}) — lower the entry',
          );
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
