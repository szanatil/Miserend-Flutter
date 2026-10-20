import 'package:flutter/foundation.dart' show ValueListenable, setEquals;
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

/// The rings a search by the position alone looks through, nearest first, a
/// wider one only when the user asks for it (CONTEXT.md, „Részletes kereső",
/// keresési kör): who searches around themselves means to go to what they
/// find, and a rare occasion looked for across the country took minutes of
/// API calls. 25 km is the surroundings, 100 km a trip still made for one
/// occasion; the maintainer set both (#84).
enum SearchRing {
  within25Km(25),
  within100Km(100),
  country(null);

  const SearchRing(this.maxKm);

  /// How far from the position the ring reaches, in straight-line km (CONTEXT
  /// .md, „Légvonal-távolság"), its far edge included; null for no limit.
  final double? maxKm;

  /// The ring „Keresés tovább" goes on to; null past the last one.
  SearchRing? get wider => index + 1 < values.length ? values[index + 1] : null;

  /// Whether a church [km] away belongs to this ring and not a narrower one.
  /// A church of no position is in the last ring alone.
  bool holds(double? km) {
    if (km == null) return maxKm == null;
    final inner = index == 0 ? null : values[index - 1].maxKm;
    return (inner == null || km > inner) && (maxKm == null || km <= maxKm!);
  }
}

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
    this.categories = defaultCategories,
    this.position,
    this.ring = SearchRing.within25Km,
  });

  /// What a search asks for unless told otherwise: masses only, as it did
  /// before the categories could be chosen (spec 0010, „Egyezés").
  static const Set<OccasionCategory> defaultCategories = {
    OccasionCategory.mass,
  };

  /// A part of the name, the common name or an alternative name.
  final String? name;

  /// A part of the city's name, so that „Buda" finds Budakeszi too, and
  /// „Budapest" every district.
  final String? city;

  /// A `nyelvek` code (CONTEXT.md, „Liturgikus nyelv jelölése").
  final String? language;

  /// The day the church has to hold an occasion on; null asks for none.
  final DateTime? day;

  /// The time window on [day] an occasion has to start in, both ends
  /// included; null ends leave the whole day open on that side.
  final TimeOfDay? from;
  final TimeOfDay? until;

  /// The categories an occasion on [day] counts in (CONTEXT.md, „Alkalom
  /// kategóriája"). Like the window, they mean nothing without a day.
  final Set<OccasionCategory> categories;

  /// The user's position, known or not. It orders the churches when no city
  /// is given; with neither a name nor a city it is what the search goes by,
  /// and [ring] says how far around it.
  final LatLng? position;

  /// The ring looked through when the position alone is searched by; it
  /// means nothing otherwise (see [searchRing]).
  final SearchRing ring;

  /// The ring the search looks through: null when a name or a city is given,
  /// as a city narrows by itself, and a name asks for a church anywhere
  /// (spec 0010, „Betöltés").
  SearchRing? get searchRing =>
      _name == null && _city == null && position != null ? ring : null;

  /// The same search, gone on to the next ring.
  AdvancedSearchCriteria widened() => _withRing(ring.wider ?? ring);

  AdvancedSearchCriteria _withRing(SearchRing ring) => AdvancedSearchCriteria(
    name: name,
    city: city,
    language: language,
    day: day,
    from: from,
    until: until,
    categories: categories,
    position: position,
    ring: ring,
  );

  /// Whether [other] asks for the same churches, perhaps in another ring.
  bool _sameSearchAs(AdvancedSearchCriteria other) =>
      _withRing(other.ring) == other;

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
      setEquals(other.categories, categories) &&
      other.position == position &&
      other.ring == ring;

  @override
  int get hashCode => Object.hash(
    _name,
    _city,
    language,
    day,
    from,
    until,
    Object.hashAllUnordered(categories),
    position,
    ring,
  );
}

/// One page of the Részletes kereső's results.
class AdvancedSearchResultPage {
  const AdvancedSearchResultPage({
    required this.churches,
    required this.hasMore,
    required this.found,
    required this.foundIsFinal,
    required this.failure,
    required this.ring,
    required this.lookedAt,
    required this.candidates,
  });

  /// The churches of the page that meet every condition, in the results'
  /// order. Each one's rows are why it matched: with a day, the occasions
  /// of the categories asked for starting in the window; without one,
  /// today's occasions of every kind, as on other lists. The cards show
  /// these rows as they are.
  final List<ChurchListEntry> churches;

  /// Whether there are candidates of the [ring] left to look at. Past the
  /// ring's last page there are none, even when a wider ring is left: that
  /// one comes only when asked for.
  final bool hasMore;

  /// The churches found up to and including this page, in every ring looked
  /// through so far. Without a day it is every candidate, known at once; with
  /// one, only the candidates looked at so far are counted, and [foundIsFinal]
  /// says whether that was all of the ring's.
  final int found;
  final bool foundIsFinal;

  /// The ring the page was looked for in; null when the search has no rings
  /// (AdvancedSearchCriteria.searchRing).
  final SearchRing? ring;

  /// How many of the ring's [candidates] — of the whole search's when it has
  /// no rings — have been looked at up to and including this page: how far
  /// the search has got.
  final int lookedAt;
  final int candidates;

  /// Why the API gave no answer for this page, even after [AdvancedSearchLoader
  /// .retryDelays]: the search stopped here, with nothing found on the page,
  /// and goes on only when started over (CONTEXT.md, „Részletes kereső",
  /// megszakadt keresés). Null when it answered or was not asked.
  final ApiFailure? failure;
}

/// Finds the churches of the Részletes kereső a page at a time (spec 0010,
/// „Betöltés"). The candidates — by name, city and language — come from the
/// cache. With a day, each page asks the API for its candidates' masses on
/// that day only, writes them through, and keeps the churches holding an
/// occasion of the categories asked for in the window; so the API is only
/// asked for what the user scrolls to.
class AdvancedSearchLoader {
  AdvancedSearchLoader({
    CacheDatabase? cache,
    MiserendApiClient? api,
    this.clock = DateTime.now,
    this.wait = Future.delayed,
    this.onChurchesGone,
  }) : _cache = cache,
       _api = api ?? MiserendApiClient();

  /// Candidates looked at per page: few enough to answer quickly and to spare
  /// mobile data, enough to fill a screen more often than not.
  static const int pageSize = 20;

  /// The waits before each retry of a page the API gave no answer for: a
  /// moving phone — on a train — loses its signal for moments, and gets it
  /// back within a quarter of a minute or not soon. Past the last one the
  /// search stops (CONTEXT.md, „Részletes kereső").
  static const List<Duration> retryDelays = [
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
  ];

  CacheDatabase? _cache;
  final MiserendApiClient _api;
  final DateTime Function() clock;

  /// Waits out a retry's delay. Injected by tests, which do not wait.
  final Future<void> Function(Duration) wait;

  /// Told when an answer reports churches removed from miserend.hu.
  final ChurchesGone? onChurchesGone;

  Future<CacheDatabase> _db() async => _cache ??= await CacheDatabase.create();

  /// Why the app's last API call got no answer, null when it got one —
  /// whichever screen made it. While it is set, the day condition is not
  /// offered: the cached days may be out of date (CONTEXT.md, „Részletes
  /// kereső").
  ValueListenable<ApiFailure?> get lastFailure => _api.status;

  /// Asks the API about one church, only to see whether it answers; the
  /// answer reaches [lastFailure].
  Future<void> checkConnection() async {
    final id = await (await _db()).firstChurchId();
    if (id == null) return;
    await _api.fetchChurches([id]);
  }

  /// The page [page] (from 0) of the results for [criteria]. The pages are
  /// asked for in order; asking for the first one again starts over. Asked
  /// for in a wider ring, the next page is the wider ring's first, and the
  /// count goes on from the narrower one's.
  Future<AdvancedSearchResultPage> loadPage(
    AdvancedSearchCriteria criteria,
    int page,
  ) async {
    final cache = await _db();
    final previous = _criteria;
    if (page == 0 || previous == null || !criteria._sameSearchAs(previous)) {
      _searchId++;
      _candidates = await _candidatesFor(cache, criteria);
      _foundThrough.clear();
      _ringStart = 0;
      _foundBeforeRing = 0;
    } else if (criteria.ring != previous.ring) {
      _candidates = await _candidatesFor(cache, criteria);
      _ringStart = page;
      _foundBeforeRing = _foundBefore(page);
    }
    _criteria = criteria;
    final candidates = _candidates;
    final start = (page - _ringStart) * pageSize;
    final slice = candidates.skip(start).take(pageSize).toList();
    final lookedAt = start + slice.length;
    final hasMore = lookedAt < candidates.length;
    AdvancedSearchResultPage result(
      List<ChurchListEntry> churches, {
      required int found,
      required bool foundIsFinal,
      ApiFailure? failure,
    }) => AdvancedSearchResultPage(
      churches: churches,
      hasMore: hasMore,
      found: found,
      foundIsFinal: foundIsFinal,
      failure: failure,
      ring: criteria.searchRing,
      lookedAt: lookedAt,
      candidates: candidates.length,
    );

    final day = criteria.day;
    if (day == null) {
      final found = _foundBeforeRing + candidates.length;
      _recordFound(page, found);
      return result(
        await _read(cache, slice, clock()),
        found: found,
        foundIsFinal: true,
      );
    }

    final searchId = _searchId;
    final foundBefore = _foundBefore(page);
    var failure = await _refreshDay(cache, slice, day);
    for (final delay in retryDelays) {
      if (failure == null) break;
      await wait(delay);
      failure = await _refreshDay(cache, slice, day);
    }
    if (failure != null) {
      // The cached day may be out of date: what is known not to be up to
      // date is no answer (CONTEXT.md, „Részletes kereső", megszakadt
      // keresés).
      return result(
        const [],
        found: foundBefore,
        foundIsFinal: false,
        failure: failure,
      );
    }
    final churches = [
      for (final church in await _read(cache, slice, day))
        if (_occasionsInWindow(church.masses, criteria) case final masses
            when masses.isNotEmpty)
          _withMasses(church, masses),
    ];
    final found = foundBefore + churches.length;
    // Started over while this page waited out its retries: the counts are
    // the newer search's.
    if (searchId == _searchId) _recordFound(page, found);
    return result(churches, found: found, foundIsFinal: !hasMore);
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

  /// The search the candidates below are for.
  AdvancedSearchCriteria? _criteria;

  /// Bumped per search started, so that a page still waiting out its
  /// retries can tell it has been overtaken.
  int _searchId = 0;
  List<ChurchListEntry> _candidates = const [];

  /// How many churches were found up to each page loaded so far.
  final List<int> _foundThrough = [];

  /// The page the ring of [_candidates] began on, and how many churches the
  /// narrower rings had found by then.
  int _ringStart = 0;
  int _foundBeforeRing = 0;

  /// Keeps [found] as the count up to [page], the pages after it let go.
  void _recordFound(int page, int found) {
    if (_foundThrough.length > page) _foundThrough.length = page;
    _foundThrough.add(found);
  }

  /// How many churches were found up to the page before [page].
  int _foundBefore(int page) =>
      page > 0 && page <= _foundThrough.length ? _foundThrough[page - 1] : 0;

  /// The churches meeting the name, city and language — and the ring, when
  /// the search has one — in the results' order (spec 0010, „Találatok"): by
  /// city and name when a city is given, else nearest first when the
  /// position is known, else by name.
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
      final ring = criteria.searchRing;
      return [
        for (final church in candidates)
          if (ring == null || ring.holds(km[church.id])) church,
      ]..sort((a, b) {
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
  /// Returns why an answer did not come, if one did not.
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
    return failures.nonNulls.firstOrNull;
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
      // Cut off at the limit, the answer may lack some of the day: the cache
      // keeps what it has.
      case ApiSuccess(:final value) when !value.complete:
        return null;
      case ApiSuccess(:final value):
        // An empty answer is an answer: the church holds nothing that day.
        await cache.replaceDailyMasses(church.id, start, [
          for (final mass in value.masses)
            if (!mass.time.isBefore(start) && mass.time.isBefore(next)) mass,
        ]);
        return null;
    }
  }

  /// The occasions of [rows] starting in the criteria's window, both ends
  /// included, in the categories asked for (spec 0010, „Egyezés"): vespers
  /// are no answer to a search for a mass (CONTEXT.md, „Alkalom
  /// kategóriája").
  static List<CachedMass> _occasionsInWindow(
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
        if (criteria.categories.contains(occasionCategory(row)) &&
            inWindow(row))
          row,
    ];
  }

  static ChurchListEntry _withMasses(
    ChurchListEntry church,
    List<CachedMass> masses,
  ) => ChurchListEntry(
    id: church.id,
    name: church.name,
    commonName: church.commonName,
    city: church.city,
    lat: church.lat,
    lon: church.lon,
    photo: church.photo,
    masses: masses,
  );
}
