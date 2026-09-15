import 'package:flutter/material.dart';
import 'package:miserend/database/cache/cache_database.dart';
import 'package:miserend/database/cache/cached_mass.dart';
import 'package:miserend/database/cache/church_details.dart';
import 'package:miserend/database/mass.dart';
import 'package:miserend/mass_filter.dart';
import 'package:sqflite/sqflite.dart';

/// Fills the cache once, from the downloaded legacy database, so the app has
/// something to show before any API call is made. This is the only place the
/// legacy recurrence columns are read; from here on the cache is fed by the
/// API alone.
class BootstrapImporter {
  /// The export is never downloaded again (ADR-0003), so this is how long a
  /// phone that never goes online keeps a full schedule. It covers the church
  /// details page's 20-day schedule with room to spare, for about a sixth of
  /// the cost of importing the export's whole 182-day window.
  static const int defaultDays = 30;

  /// Churches per transaction. The import covers every church the app knows
  /// about, so it runs in chunks: one transaction per church would dominate
  /// the runtime, and holding every expanded mass in memory at once would not
  /// fit comfortably on a phone.
  static const int _chunkSize = 250;

  static Future<void> run({
    required Database legacy,
    required CacheDatabase cache,
    required DateTime from,
    int days = defaultDays,
  }) async {
    final churches = await legacy.query('templomok');

    for (var start = 0; start < churches.length; start += _chunkSize) {
      final chunk = churches.skip(start).take(_chunkSize).toList();
      final ids = chunk.map((row) => row['tid'] as int).toList();

      final placeholders = List.filled(ids.length, '?').join(',');
      final rules = await legacy.query('misek',
          where: 'tid IN ($placeholders)', whereArgs: ids);

      final rulesByChurch = <int, List<Mass>>{};
      for (final row in rules) {
        final rule = _toRule(row);
        (rulesByChurch[rule.churchId ?? 0] ??= <Mass>[]).add(rule);
      }

      final masses = <CachedMass>[];
      for (final id in ids) {
        masses.addAll(expandMasses(rulesByChurch[id] ?? const <Mass>[],
            from: from, days: days));
      }

      await cache.importChurches(
          chunk.map(churchFromLegacyRow).toList(), masses);
    }
    await cache.setBootstrappedAt(DateTime.now());
  }

  static ChurchDetails churchFromLegacyRow(Map<String, Object?> row) {
    final photo = row['kep'] as String?;
    return ChurchDetails(
      id: row['tid'] as int,
      name: row['nev'] as String?,
      commonName: row['ismertnev'] as String?,
      names: const [],
      alternativeNames: const [],
      country: row['orszag'] as String?,
      diocese: null,
      county: row['megye'] as String?,
      city: row['varos'] as String?,
      street: row['cim'] as String?,
      gettingThere: row['megkozelites'] as String?,
      parish: null,
      description: null,
      accessibility: null,
      email: null,
      links: const [],
      languages: const [],
      massScheduleNote: null,
      adorations: const [],
      hasConfession: null,
      communities: const [],
      lat: row['lat'] as double?,
      lon: row['lng'] as double?,
      photos: photo == null || photo.isEmpty ? const [] : [photo],
      updatedAt: null,
      localSyncedAt: null,
      isGreek: row['gorog'] == null ? null : row['gorog'] == 1,
    );
  }

  /// Every occurrence the [rules] produce over [days] days starting on [from],
  /// using the same day-matching logic the app already renders with.
  static List<CachedMass> expandMasses(
    List<Mass> rules, {
    required DateTime from,
    int days = defaultDays,
  }) {
    final start = DateTime(from.year, from.month, from.day);
    final occurrences = <String, CachedMass>{};

    for (var offset = 0; offset < days; offset++) {
      final day = start.add(Duration(days: offset));
      for (final rule in rules) {
        final time = rule.time;
        if (time == null || !MassFilter.isMassOnDay(rule, day)) continue;

        final at =
            DateTime(day.year, day.month, day.day, time.hour, time.minute);
        // Overlapping seasons can describe the same mass twice; two masses at
        // one time are only genuinely different if they say different things.
        occurrences.putIfAbsent(
          '${at.toIso8601String()}|${rule.comment ?? ''}',
          () => CachedMass(
            id: null,
            apiMassId: null,
            churchId: rule.churchId ?? 0,
            time: at,
            info: rule.comment,
            source: MassSource.bootstrap,
          ),
        );
      }
    }

    final masses = occurrences.values.toList();
    masses.sort((a, b) => a.time.compareTo(b.time));
    return masses;
  }

  static Mass _toRule(Map<String, Object?> row) {
    final time = row['ido'] as String?;
    return Mass(
      id: row['mid'] as int?,
      churchId: row['tid'] as int?,
      day: row['nap'] as int?,
      time: time == null ? null : _parseTime(time),
      season: row['idoszak'] as String?,
      language: row['nyelv'] as String?,
      tags: row['milyen'] as String?,
      period: row['periodus'] as String?,
      weight: row['suly'] as int?,
      startDate: row['datumtol'] as int?,
      endDate: row['datumig'] as int?,
      comment: row['megjegyzes'] as String?,
    );
  }

  static TimeOfDay? _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }
}
