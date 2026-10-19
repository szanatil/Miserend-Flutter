import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The mechanical half of DESIGN.md (EH2): raw design values outside
/// `lib/theme/` (TO1), non-rounded icons (IK1) and icon sizes given to the
/// icon rather than taken from the theme (IK3). The other rules are left to
/// the review.
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

/// The rules an expression can spread over several lines for: each match
/// counts as one line.
final Map<String, RegExp> _expressionRules = {
  'iconSize': RegExp(r'\bIcon\((?:[^()]|\([^()]*\))*?\bsize\s*:'),
};

/// The known deviations found by the design audit of 2026-10-07, as the
/// number of offending lines per file and rule, each with the issue that
/// removes it. A count may only fall: a new deviation fails the test, and a
/// fixed one fails it too until its entry is lowered or removed, so the list
/// never hides a regression behind a fix.
const Map<String, Map<String, (int, String)>> _knownDeviations = {};

/// Counts the lines of each `lib/` file outside `lib/theme/` that match a
/// rule, and the expressions that match an expression rule, skipping comment
/// lines.
Map<String, Map<String, int>> _scan() {
  final found = <String, Map<String, int>>{};
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !f.path.startsWith('lib/theme/'));
  for (final file in files) {
    final lines = file.readAsLinesSync();
    final source = lines
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');
    for (final rule in _expressionRules.entries) {
      final count = rule.value.allMatches(source).length;
      if (count > 0) {
        final counts = found.putIfAbsent(file.path, () => {});
        counts[rule.key] = (counts[rule.key] ?? 0) + count;
      }
    }
    for (final line in lines) {
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
            '(DESIGN.md TO1/IK1/IK3; new deviations are not allowed)',
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
