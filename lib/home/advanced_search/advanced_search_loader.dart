import 'package:flutter/material.dart' show TimeOfDay;
import 'package:latlong2/latlong.dart';
import 'package:miserend/api/api_result.dart';
import 'package:miserend/api/cache_write_through.dart';
import 'package:miserend/api/miserend_api_client.dart';
import 'package:miserend/database/cache/cache_database.dart';
import 'package:miserend/database/cache/cached_mass.dart';
import 'package:miserend/database/cache/church_details.dart';
import 'package:miserend/database/cache/church_list_entry.dart';
import 'package:miserend/database/cache/church_location.dart';
import 'package:miserend/database/cache/search_text.dart';
import 'package:miserend/mass_kind.dart';
import 'package:miserend/straight_line_distance.dart';

/// What the Részletes kereső looks for (CONTEXT.md, „Részletes kereső"). Every
/// condition given has to hold; a null or blank one is not a condition.
class AdvancedSearchCriteria {
  const AdvancedSearchCriteria({
    this.name,
    this.city,
    this.language,
    this.day,
    this.from,
    this.until,
    this.position,
  });

  /// A part of the name, the common name or an alternative name.
  final String? name;

  /// A part of the city's name, so that „Buda" finds Budakeszi too, and
  /// „Budapest" every district.
  final String? city;

  /// A `nyelvek` code (CONTEXT.md, „Liturgikus nyelv jelölése").
  final String? language;

  /// The day the church has to hold a mass on; null asks for no mass at all.
  final DateTime? day;

  /// The time window on [day] a mass has to start in, both ends included;
  /// null ends leave the whole day open on that side.
  final TimeOfDay? from;
  final TimeOfDay? until;

  /// The user's position, known or not. It orders the churches when no city
  /// is given, and stands in for a name or a city as the condition that
  /// narrows the search to the user's surroundings.
  final LatLng? position;

  String? get _name => _given(name);
  String? get _city => _given(city);

  static String? _given(String? text) {
    final trimmed = text?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// The position the results are ordered by, nearest first — and so the one
  /// the cards measure their distance from; null when a city orders them or
  /// the position is unknown (spec 0010, „Találatok").
  LatLng? get distanceOrderFrom => _city == null ? position : null;

  /// Whether there is enough to search by: a search by language or day alone
  /// would list the whole country, so a name, a city or the position is
  /// needed (spec 0010, „Kötelező").
  bool get canSearch => _name != null || _city != null || position != null;

  @override
  bool operator ==(Object other) =>
      other is AdvancedSearchCriteria &&
      other._name == _name &&
      other._city == _city &&
      other.language == language &&
      other.day == day &&
      other.from == from &&
      other.until == until &&
      other.position == position;

  @override
  int get hashCode =>
      Object.hash(_name, _city, language, day, from, until, position);
}

/// One page of the Részletes kereső's results.
class AdvancedSearchResultPage {
  const AdvancedSearchResultPage({
    required this.churches,
    required this.hasMore,
    required this.found,
    required this.foundIsFinal,
    required this.failure,
    required this.dataAsOf,
  });

  /// The churches of the page that meet every condition, in the results'
  /// order. Each one's masses are why it matched: with a day, the masses
  /// starting in the window; without one, today's rows, as on other lists.
  final List<ChurchListEntry> churches;

  /// Whether there are candidates left to look at.
  final bool hasMore;

  /// The churches found up to and including this page. Without a day it is
  /// every candidate, known at once; with one, only the candidates looked at
  /// so far are counted, and [foundIsFinal] says whether that was all of them.
  final int found;
  final bool foundIsFinal;

  /// Why the API gave no answer for this page, which was then decided from
  /// the cached masses; null when it answered or was not asked.
  final ApiFailure? failure;

  /// The last successful search, or the bootstrap import before one.
  final DateTime? dataAsOf;
}

/// Finds the churches of the Részletes kereső a page at a time (spec 0010,
/// „Betöltés"). The candidates — by name, city and language — come from the
/// cache. With a day, each page asks the API for its candidates' masses on
/// that day only, writes them through, and keeps the churches holding a mass
/// in the window; so the API is only asked for what the user scrolls to.
class AdvancedSearchLoader {
  AdvancedSearchLoader({
    CacheDatabase? cache,
    MiserendApiClient? api,
    this.clock = DateTime.now,
    this.onChurchesGone,
  }) : _cache = cache,
       _api = api ?? MiserendApiClient();

  /// Candidates looked at per page: few enough to answer quickly and to spare
  /// mobile data, enough to fill a screen more often than not.
  static const int pageSize = 20;

  CacheDatabase? _cache;
  final MiserendApiClient _api;
  final DateTime Function() clock;

  /// Told when an answer reports churches removed from miserend.hu.
  final ChurchesGone? onChurchesGone;

  Future<CacheDatabase> _db() async => _cache ??= await CacheDatabase.create();

  /// The page [page] (from 0) of the results for [criteria]. The pages are
  /// asked for in order; asking for the first one again starts over.
  Future<AdvancedSearchResultPage> loadPage(
    AdvancedSearchCriteria criteria,
    int page,
  ) async {
    final cache = await _db();
    if (page == 0 || criteria != _criteria) {
      _criteria = criteria;
      _candidates = await _candidatesFor(cache, criteria);
      _foundThrough.clear();
    }
    final candidates = _candidates;
    final start = page * pageSize;
    final slice = candidates.skip(start).take(pageSize).toList();
    final hasMore = start + slice.length < candidates.length;

    final day = criteria.day;
    if (day == null) {
      return AdvancedSearchResultPage(
        churches: await _read(cache, slice, clock()),
        hasMore: hasMore,
        found: candidates.length,
        foundIsFinal: true,
        failure: null,
        dataAsOf: await _dataAsOf(cache),
      );
    }

    final failure = await _refreshDay(cache, slice, day);
    final churches = [
      for (final church in await _read(cache, slice, day))
        if (_massesInWindow(church.masses, criteria) case final masses
            when masses.isNotEmpty)
          ChurchListEntry(
            id: church.id,
            name: church.name,
            commonName: church.commonName,
            city: church.city,
            lat: church.lat,
            lon: church.lon,
            photo: church.photo,
            masses: masses,
          ),
    ];
    final foundBefore =
        page > 0 && page <= _foundThrough.length ? _foundThrough[page - 1] : 0;
    final found = foundBefore + churches.length;
    if (_foundThrough.length > page) _foundThrough.length = page;
    _foundThrough.add(found);
    return AdvancedSearchResultPage(
      churches: churches,
      hasMore: hasMore,
      found: found,
      foundIsFinal: !hasMore,
      failure: failure,
      dataAsOf: await _dataAsOf(cache),
    );
  }

  /// Cities whose name contains [term], for the city field's suggestions.
  Future<List<String>> cities(String term) async =>
      (await _db()).searchCities(term);

  /// The `nyelvek` codes some cached church carries, Hungarian left out: it
  /// holds for nearly every church, and would narrow nothing.
  Future<List<String>> languages() async => [
    for (final code in await (await _db()).languages())
      if (code != _hungarian) code,
  ];

  static const String _hungarian = 'hu';

  /// Names the search, whose last successful answer dates the data shown.
  static const String _syncKey = 'list:advancedSearch';

  /// The search the candidates below are for.
  AdvancedSearchCriteria? _criteria;
  List<ChurchListEntry> _candidates = const [];

  /// How many churches were found up to each page loaded so far.
  final List<int> _foundThrough = [];

  /// The churches meeting the name, city and language, in the results' order
  /// (spec 0010, „Találatok"): by city and name when a city is given, else
  /// nearest first when the position is known, else by name.
  Future<List<ChurchListEntry>> _candidatesFor(
    CacheDatabase cache,
    AdvancedSearchCriteria criteria,
  ) async {
    final candidates = await cache.advancedSearchCandidates(
      name: criteria._name,
      city: criteria._city,
      language: criteria.language,
    );
    final position = criteria.distanceOrderFrom;
    if (criteria._city != null) {
      return candidates..sort((a, b) {
        final byCity = searchText(
          a.city ?? '',
        ).compareTo(searchText(b.city ?? ''));
        return byCity != 0 ? byCity : CacheDatabase.compareByName(a, b);
      });
    }
    if (position != null) {
      final km = {
        for (final church in candidates)
          church.id: straightLineKm(position, church.lat, church.lon),
      };
      return candidates..sort((a, b) {
        final (x, y) = (km[a.id], km[b.id]);
        if (x == null || y == null) {
          // Churches with no position go last; among themselves, by name.
          if (x != y) return x == null ? 1 : -1;
          return CacheDatabase.compareByName(a, b);
        }
        return x.compareTo(y);
      });
    }
    return candidates..sort(CacheDatabase.compareByName);
  }

  /// [slice] read again with its rows of [day], in [slice]'s order. A church
  /// the API reported removed is no longer in the cache, and drops out.
  Future<List<ChurchListEntry>> _read(
    CacheDatabase cache,
    List<ChurchListEntry> slice,
    DateTime day,
  ) async {
    final read = {
      for (final church in await cache.churchesByIds([
        for (final church in slice) church.id,
      ], day))
        church.id: church,
    };
    return [
      for (final church in slice)
        if (read[church.id] case final found?) found,
    ];
  }

  /// Asks the API about [slice]'s churches, then for each one's masses on
  /// [day], and writes the answers through. The masses come from the same
  /// call the details page builds its schedule with (ADR-0002, spec 0003);
  /// the `Church` call is what reports a church removed from miserend.hu.
  /// Returns why an answer did not come, if one did not; the churches it
  /// concerns keep their cached rows.
  Future<ApiFailure?> _refreshDay(
    CacheDatabase cache,
    List<ChurchListEntry> slice,
    DateTime day,
  ) async {
    if (slice.isEmpty) return null;
    final now = clock();
    final ChurchesResponse churches;
    switch (await _api.fetchChurches([for (final church in slice) church.id])) {
      case ApiFailed(:final failure):
        return failure;
      case ApiSuccess(:final value):
        churches = value;
    }
    await CacheWriteThrough(
      cache,
      onChurchesGone: onChurchesGone,
    ).write(churches, today: now, minimal: true);

    final failures = await Future.wait([
      for (final church in churches.churches)
        if (ChurchLocation.isKnown(church.lat, church.lon))
          _refreshMasses(cache, church, day),
    ]);
    final failure = failures.nonNulls.firstOrNull;
    if (failure == null) await cache.setSyncTime(_syncKey, now);
    return failure;
  }

  Future<ApiFailure?> _refreshMasses(
    CacheDatabase cache,
    ChurchDetails church,
    DateTime day,
  ) async {
    final start = DateTime(day.year, day.month, day.day);
    final next = DateTime(day.year, day.month, day.day + 1);
    switch (await _api.fetchMassesForChurch(
      churchId: church.id,
      lat: church.lat!,
      lon: church.lon!,
      from: start,
      until: next,
    )) {
      case ApiFailed(:final failure):
        return failure;
      case ApiSuccess(:final value):
        // An empty answer is an answer: the church holds nothing that day.
        await cache.replaceDailyMasses(church.id, start, [
          for (final mass in value)
            if (!mass.time.isBefore(start) && mass.time.isBefore(next)) mass,
        ]);
        return null;
    }
  }

  /// The masses of [rows] starting in the criteria's window, both ends
  /// included (spec 0010, „Egyezés"). Only masses count: confession or
  /// vespers are no answer to a search for a mass (CONTEXT.md, „Mise vs.
  /// egyéb liturgikus esemény").
  static List<CachedMass> _massesInWindow(
    List<CachedMass> rows,
    AdvancedSearchCriteria criteria,
  ) {
    int minutes(TimeOfDay time) => time.hour * 60 + time.minute;
    final from = criteria.from;
    final until = criteria.until;
    bool inWindow(CachedMass row) {
      final start = minutes(TimeOfDay.fromDateTime(row.time));
      return (from == null || start >= minutes(from)) &&
          (until == null || start <= minutes(until));
    }

    return [
      for (final row in rows)
        if (isMass(row) && inWindow(row)) row,
    ];
  }

  Future<DateTime?> _dataAsOf(CacheDatabase cache) async =>
      await cache.syncTime(_syncKey) ?? await cache.bootstrappedAt();
}
