import 'dart:convert';
import 'dart:math';

import 'package:miserend/database/cache/adoration.dart';
import 'package:miserend/database/cache/cached_mass.dart';
import 'package:miserend/database/cache/church_details.dart';
import 'package:miserend/database/cache/church_list_entry.dart';
import 'package:miserend/database/cache/church_location.dart';
import 'package:miserend/database/cache/community.dart';
import 'package:miserend/database/cache/search_text.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// The write-through cache behind the v4 API, and every screen's data source
/// (ADR-0003). It is a separate file from the downloaded `miserend.sqlite3`,
/// which only the one-time bootstrap import reads.
class CacheDatabase {
  static const String databaseName = 'miserend_cache.sqlite3';

  static const String churchesTable = 'churches_cache';
  static const String massesTable = 'masses_cache';
  static const String syncTable = 'sync_state';

  late Database db;

  /// [path] exists for tests, which open an in-memory database.
  static Future<CacheDatabase> create({String? path}) async {
    final CacheDatabase instance = CacheDatabase();
    await instance.openDb(path ?? join(await getDatabasesPath(), databaseName));
    return instance;
  }

  Future<void> openDb(String path) async {
    db = await openDatabase(
      path,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE $churchesTable('
          'id INTEGER PRIMARY KEY, '
          'nev TEXT, '
          'ismertnev TEXT, '
          'names TEXT, '
          'alternative_names TEXT, '
          'orszag TEXT, '
          'egyhazmegye TEXT, '
          'megye TEXT, '
          'varos TEXT, '
          'cim TEXT, '
          'megkozelites TEXT, '
          'plebania TEXT, '
          'leiras TEXT, '
          'accessibility TEXT, '
          'email TEXT, '
          'links TEXT, '
          'nyelvek TEXT, '
          'miserend_megjegyzes TEXT, '
          'adoraciok TEXT, '
          'gyontatas INTEGER, '
          'kozossegek TEXT, '
          'lat REAL, '
          'lon REAL, '
          'photos TEXT, '
          'frissitve TEXT, '
          'local_synced_at TEXT, '
          'gorog INTEGER, '
          'kereses_nev TEXT, '
          'kereses_alt_nevek TEXT, '
          'kereses_varos TEXT)',
        );
        await db.execute(
          'CREATE TABLE $massesTable('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'api_mass_id INTEGER, '
          'church_id INTEGER NOT NULL, '
          'idopont TEXT NOT NULL, '
          'informacio TEXT, '
          'forras TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE INDEX idx_masses_cache_church_time '
          'ON $massesTable(church_id, idopont)',
        );
        await _createSyncTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createSyncTable(db);
        }
        if (oldVersion < 3) {
          // Only the details page wrote API rows before, and only those carry
          // an API mass id.
          await db.execute(
            'ALTER TABLE $massesTable ADD COLUMN forras TEXT NOT NULL '
            "DEFAULT '${MassSource.bootstrap.name}'",
          );
          await db.execute(
            'UPDATE $massesTable SET forras = '
            "'${MassSource.nearbyMasses.name}' WHERE api_mass_id IS NOT NULL",
          );
        }
        if (oldVersion < 4) {
          for (final column in _searchColumns) {
            await db.execute(
              'ALTER TABLE $churchesTable ADD COLUMN $column TEXT',
            );
          }
          final rows = await db.query(
            churchesTable,
            columns: ['id', 'nev', 'ismertnev', 'alternative_names', 'varos'],
          );
          final batch = db.batch();
          for (final row in rows) {
            batch.update(
              churchesTable,
              _searchRow(
                name: row['nev'] as String?,
                commonName: row['ismertnev'] as String?,
                alternativeNames: _stringList(row['alternative_names']),
                city: row['varos'] as String?,
              ),
              where: 'id = ?',
              whereArgs: [row['id']],
            );
          }
          await batch.commit(noResult: true);
        }
      },
      version: 4,
    );
  }

  /// The church columns folded by [searchText], which the local search
  /// compares against: SQLite cannot fold accents itself, and sqflite cannot
  /// teach it (#12). Written with every church row.
  static const List<String> _searchColumns = [
    'kereses_nev',
    'kereses_alt_nevek',
    'kereses_varos',
  ];

  /// The name and common name share a column because a response carries
  /// either both or neither; the alternative names have their own, because a
  /// `minimal` response leaves them out. A newline separates the parts, so a
  /// term typed into the search bar cannot match across two of them.
  static Map<String, Object?> _searchRow({
    required String? name,
    required String? commonName,
    required List<String> alternativeNames,
    required String? city,
  }) => {
    'kereses_nev': searchText([name, commonName].nonNulls.join('\n')),
    'kereses_alt_nevek': searchText(alternativeNames.join('\n')),
    'kereses_varos': city == null ? null : searchText(city),
  };

  /// When things happened to the cache as a whole, as opposed to one church:
  /// the bootstrap import, a list's last successful refresh.
  static Future<void> _createSyncTable(Database db) => db.execute(
    'CREATE TABLE $syncTable(kulcs TEXT PRIMARY KEY, idopont TEXT NOT NULL)',
  );

  static const String _bootstrapKey = 'bootstrap';

  /// When the bootstrap import filled the cache, or null if that was never
  /// recorded. It is how old the data is on a row no API response has touched.
  Future<DateTime?> bootstrappedAt() => syncTime(_bootstrapKey);

  Future<void> setBootstrappedAt(DateTime time) =>
      setSyncTime(_bootstrapKey, time);

  Future<DateTime?> syncTime(String key) async {
    final rows = await db.query(
      syncTable,
      where: 'kulcs = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _parseDateTime(rows.first['idopont'] as String?);
  }

  Future<void> setSyncTime(String key, DateTime time) async {
    await db.insert(syncTable, {
      'kulcs': key,
      'idopont': _formatDateTime(time),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<ChurchDetails?> getChurch(int id) async {
    final rows = await db.query(
      churchesTable,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return _toChurch(rows.first);
  }

  /// Churches with at least one photo; the Menü page's recommendation shows
  /// one, so a church without is never picked.
  static const String _photographed = "photos IS NOT NULL AND photos <> '[]'";

  /// How many churches have a photo; with [photographedChurchAt], picks one
  /// without reading them all.
  Future<int> photographedChurchCount() async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM $churchesTable WHERE $_photographed',
    );
    return rows.first['n'] as int;
  }

  /// The photographed church at [index] in id order, which stays put while
  /// the cache only gains rows; null past the end.
  Future<ChurchDetails?> photographedChurchAt(int index) async {
    final rows = await db.query(
      churchesTable,
      where: _photographed,
      orderBy: 'id',
      limit: 1,
      offset: index,
    );
    if (rows.isEmpty) return null;
    return _toChurch(rows.first);
  }

  /// The columns a `minimal` API response carries. The others — photos,
  /// description, names, address and the rest — are absent from it, not
  /// empty, so they must not overwrite what the cache already holds. The
  /// folded alternative names stay for the same reason.
  static const Set<String> _minimalColumns = {
    'nev',
    'ismertnev',
    'orszag',
    'varos',
    'lat',
    'lon',
    'links',
    'adoraciok',
    'gyontatas',
    'frissitve',
    'kereses_nev',
    'kereses_varos',
  };

  /// Writes an API response over the cached row. A column the API does not
  /// carry — `gorog` — keeps whatever the bootstrap import put there, and so
  /// do the columns a [minimal] response leaves out.
  Future<void> upsertChurch(
    ChurchDetails church, {
    bool minimal = false,
  }) async {
    final row = _toRow(church);
    if (minimal) {
      row.removeWhere((column, _) => !_minimalColumns.contains(column));
    }
    final values = {...row, 'local_synced_at': _formatDateTime(DateTime.now())};
    final updated = await db.update(
      churchesTable,
      values,
      where: 'id = ?',
      whereArgs: [church.id],
    );
    if (updated == 0) {
      await db.insert(churchesTable, {...values, 'id': church.id});
    }
  }

  /// The bootstrap import's bulk write: one transaction for the whole chunk,
  /// because doing this a row at a time costs a transaction per church and the
  /// import covers every church the app knows. It writes no
  /// `local_synced_at` — these rows have never seen an API response.
  Future<void> importChurches(
    List<ChurchDetails> churches,
    List<CachedMass> masses,
  ) async {
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final church in churches) {
        batch.insert(churchesTable, {
          ..._toRow(church),
          'id': church.id,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        batch.delete(
          massesTable,
          where: 'church_id = ?',
          whereArgs: [church.id],
        );
      }
      for (final mass in masses) {
        batch.insert(massesTable, _massRow(mass));
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> replaceMassesForChurch(
    int churchId,
    List<CachedMass> masses,
  ) async {
    final batch = db.batch();
    batch.delete(massesTable, where: 'church_id = ?', whereArgs: [churchId]);
    for (final mass in masses) {
      batch.insert(massesTable, _massRow(mass));
    }
    await batch.commit(noResult: true);
  }

  /// Puts a list answer's rows for [day] in place of the day's cached rows,
  /// whichever source those came from. miserend.hu builds a list answer's
  /// `misek` and the details page's schedule from the same index, so the list
  /// answer is just as fresh; the other days are left alone (spec 0005,
  /// „Gyorsítótár-írás").
  Future<void> replaceDailyMasses(
    int churchId,
    DateTime day,
    List<CachedMass> masses,
  ) async {
    final (from, until) = _dayBounds(day);
    final batch = db.batch();
    batch.delete(
      massesTable,
      where: 'church_id = ? AND idopont >= ? AND idopont < ?',
      whereArgs: [churchId, from, until],
    );
    for (final mass in masses) {
      batch.insert(massesTable, _massRow(mass));
    }
    await batch.commit(noResult: true);
  }

  /// The stored text of [day]'s midnight and of the next one.
  (String, String) _dayBounds(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    return (
      _formatDateTime(start)!,
      _formatDateTime(DateTime(start.year, start.month, start.day + 1))!,
    );
  }

  Map<String, Object?> _massRow(CachedMass mass) => {
    'api_mass_id': mass.apiMassId,
    'church_id': mass.churchId,
    'idopont': _formatDateTime(mass.time),
    'informacio': mass.info,
    'forras': mass.source.name,
  };

  Future<List<CachedMass>> getMassesForChurch(
    int churchId, {
    DateTime? from,
    DateTime? until,
  }) async {
    final where = StringBuffer('church_id = ?');
    final args = <Object>[churchId];
    if (from != null) {
      where.write(' AND idopont >= ?');
      args.add(_formatDateTime(from)!);
    }
    if (until != null) {
      where.write(' AND idopont <= ?');
      args.add(_formatDateTime(until)!);
    }

    final rows = await db.query(
      massesTable,
      where: where.toString(),
      whereArgs: args,
      orderBy: 'idopont',
    );
    return rows.map(_toMass).toList();
  }

  /// Every church with a position, nearest to ([lat], [lon]) first, with its
  /// rows of [day]. Unbounded: the list shows them all.
  Future<List<ChurchListEntry>> nearChurches(
    double lat,
    double lon,
    DateTime day,
  ) async {
    // Degrees of longitude shrink towards the poles; scaling them keeps the
    // order right without trigonometry in SQL.
    final lonScale = cos(lat * pi / 180);
    final rows = await db.rawQuery(
      'SELECT $_listColumns FROM $churchesTable '
      'WHERE ${ChurchLocation.knownSql} '
      'ORDER BY (lat - ?) * (lat - ?) + '
      '(lon - ?) * (lon - ?) * ? * ?, id',
      [lat, lat, lon, lon, lonScale, lonScale],
    );
    return _listEntries(rows, day);
  }

  /// Churches whose name, common name, one of the alternative names or city
  /// contains [term], with their rows of [day] — none when [day] is null, as
  /// for the suggestions typed out a key at a time. The term is taken
  /// literally, but case and accents do not count (#12). The city is searched
  /// too, as the API's `Search` does, which the results page falls back to.
  ///
  /// The churches found by a name come first, each part by name: a city
  /// matches many churches at once, and would otherwise push the one typed
  /// out of the suggestions' first few.
  Future<List<ChurchListEntry>> searchChurches(
    String term,
    DateTime? day,
  ) async {
    final folded = searchText(term);
    final rows = await db.rawQuery(
      'SELECT $_listColumns, '
      'instr(kereses_nev, ?) > 0 OR instr(kereses_alt_nevek, ?) > 0 '
      'AS nevben FROM $churchesTable '
      'WHERE nevben OR instr(kereses_varos, ?) > 0',
      [folded, folded, folded],
    );
    final nameMatchIds = {
      for (final row in rows)
        if (row['nevben'] == 1) row['id'] as int,
    };
    final sorted = _byName(await _listEntries(rows, day));
    return [
      ...sorted.where((church) => nameMatchIds.contains(church.id)),
      ...sorted.where((church) => !nameMatchIds.contains(church.id)),
    ];
  }

  /// The churches of [city], by name, with their rows of [day].
  Future<List<ChurchListEntry>> churchesInCity(
    String city,
    DateTime day,
  ) async {
    final rows = await db.query(
      churchesTable,
      columns: _listColumns.split(', '),
      where: 'varos = ?',
      whereArgs: [city],
    );
    return _byName(await _listEntries(rows, day));
  }

  /// Cities whose name contains [term], each once; case and accents do not
  /// count, as in [searchChurches].
  Future<List<String>> searchCities(String term) async {
    final rows = await db.query(
      churchesTable,
      distinct: true,
      columns: ['varos'],
      where: 'instr(kereses_varos, ?) > 0',
      whereArgs: [searchText(term)],
    );
    return rows.map((row) => row['varos'] as String).toList();
  }

  /// The Részletes kereső's candidates: the churches meeting every condition
  /// given, in no particular order and without their masses (spec 0010,
  /// „Egyezés"). [name] is a part of the name, the common name or an
  /// alternative name, [city] a part of the city, both folded as in
  /// [searchChurches]; [language] a `nyelvek` code.
  Future<List<ChurchListEntry>> advancedSearchCandidates({
    String? name,
    String? city,
    String? language,
  }) async {
    final where = <String>[];
    final args = <Object>[];
    if (name != null) {
      final folded = searchText(name);
      where.add(
        '(instr(kereses_nev, ?) > 0 OR instr(kereses_alt_nevek, ?) > 0)',
      );
      args.addAll([folded, folded]);
    }
    if (city != null) {
      where.add('instr(kereses_varos, ?) > 0');
      args.add(searchText(city));
    }
    if (language != null) {
      // The codes are stored as a JSON list; the quotes keep „hu" from
      // matching inside a longer code.
      where.add('instr(nyelvek, ?) > 0');
      args.add(jsonEncode(language));
    }
    final rows = await db.query(
      churchesTable,
      columns: _listColumns.split(', '),
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args,
    );
    return _listEntries(rows, null);
  }

  /// Every `nyelvek` code some cached church carries, each once, sorted.
  Future<List<String>> languages() async {
    final rows = await db.query(
      churchesTable,
      distinct: true,
      columns: ['nyelvek'],
      where: "nyelvek IS NOT NULL AND nyelvek <> '[]'",
    );
    return {for (final row in rows) ..._stringList(row['nyelvek'])}.toList()
      ..sort();
  }

  /// The churches with these ids that the cache holds, by name, with their
  /// rows of [day].
  Future<List<ChurchListEntry>> churchesByIds(
    List<int> ids,
    DateTime day,
  ) async {
    if (ids.isEmpty) return const [];
    final rows = await db.query(
      churchesTable,
      columns: _listColumns.split(', '),
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
    return _byName(await _listEntries(rows, day));
  }

  /// SQLite's NOCASE only folds ASCII, which would put "Ágota" after "Zirci".
  /// The folded name orders the way a reader expects closely enough for a
  /// short list.
  static List<ChurchListEntry> _byName(List<ChurchListEntry> entries) =>
      entries..sort(compareByName);

  /// [_byName]'s order, for lists sorted elsewhere.
  static int compareByName(ChurchListEntry a, ChurchListEntry b) {
    final byName = searchText(a.name ?? '').compareTo(searchText(b.name ?? ''));
    return byName != 0 ? byName : a.id.compareTo(b.id);
  }

  /// Forgets churches miserend.hu no longer has, with their masses.
  Future<void> deleteChurches(List<int> ids) async {
    if (ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(',');
    final batch = db.batch();
    batch.delete(
      massesTable,
      where: 'church_id IN ($placeholders)',
      whereArgs: ids,
    );
    batch.delete(churchesTable, where: 'id IN ($placeholders)', whereArgs: ids);
    await batch.commit(noResult: true);
  }

  /// Every church with a position, for the map's markers.
  Future<List<ChurchLocation>> churchLocations() async {
    final rows = await db.query(
      churchesTable,
      columns: ['id', 'lat', 'lon'],
      where: ChurchLocation.knownSql,
    );
    return [
      for (final row in rows)
        ChurchLocation(
          id: row['id'] as int,
          lat: (row['lat'] as num).toDouble(),
          lon: (row['lon'] as num).toDouble(),
        ),
    ];
  }

  static const String _listColumns =
      'id, nev, ismertnev, varos, lat, lon, photos';

  /// [day] null reads no masses at all.
  Future<List<ChurchListEntry>> _listEntries(
    List<Map<String, Object?>> rows,
    DateTime? day,
  ) async {
    final masses =
        day == null
            ? const <int, List<CachedMass>>{}
            : await _massesOn(
              day,
              churchIds:
                  rows.length <= _idListLimit
                      ? [for (final row in rows) row['id'] as int]
                      : null,
            );
    return rows.map((row) {
      final id = row['id'] as int;
      final photos = _stringList(row['photos']);
      return ChurchListEntry(
        id: id,
        name: row['nev'] as String?,
        commonName: row['ismertnev'] as String?,
        city: row['varos'] as String?,
        lat: row['lat'] as double?,
        lon: row['lon'] as double?,
        photo: photos.isEmpty ? null : photos.first,
        masses: masses[id] ?? const <CachedMass>[],
      );
    }).toList();
  }

  /// Below SQLite's default limit of 999 bound parameters.
  static const int _idListLimit = 900;

  /// Every cached row of [day], by church — of [churchIds] only, when given.
  /// One query for the whole list rather than one per church.
  Future<Map<int, List<CachedMass>>> _massesOn(
    DateTime day, {
    List<int>? churchIds,
  }) async {
    if (churchIds != null && churchIds.isEmpty) return const {};
    final (from, until) = _dayBounds(day);
    final where = StringBuffer('idopont >= ? AND idopont < ?');
    if (churchIds != null) {
      where.write(
        ' AND church_id IN (${List.filled(churchIds.length, '?').join(',')})',
      );
    }
    final rows = await db.query(
      massesTable,
      where: where.toString(),
      whereArgs: [from, until, ...?churchIds],
      orderBy: 'idopont',
    );
    final byChurch = <int, List<CachedMass>>{};
    for (final row in rows) {
      final mass = _toMass(row);
      (byChurch[mass.churchId] ??= <CachedMass>[]).add(mass);
    }
    return byChurch;
  }

  Map<String, Object?> _toRow(ChurchDetails church) {
    return {
      'nev': church.name,
      'ismertnev': church.commonName,
      'names': jsonEncode(church.names),
      'alternative_names': jsonEncode(church.alternativeNames),
      'orszag': church.country,
      'egyhazmegye': church.diocese,
      'megye': church.county,
      'varos': church.city,
      'cim': church.street,
      'megkozelites': church.gettingThere,
      'plebania': church.parish,
      'leiras': church.description,
      'accessibility':
          church.accessibility == null
              ? null
              : jsonEncode(church.accessibility),
      'email': church.email,
      'links': jsonEncode(church.links),
      'nyelvek': jsonEncode(church.languages),
      'miserend_megjegyzes': church.massScheduleNote,
      'adoraciok': jsonEncode(
        church.adorations
            .map(
              (a) => {
                'kezdete': _formatDateTime(a.start),
                'vege': _formatDateTime(a.end),
                'fajta': a.kind,
                'info': a.info,
              },
            )
            .toList(),
      ),
      'gyontatas':
          church.hasConfession == null ? null : (church.hasConfession! ? 1 : 0),
      'kozossegek': jsonEncode(
        church.communities.map((c) => {'nev': c.name, 'link': c.link}).toList(),
      ),
      'lat': church.lat,
      'lon': church.lon,
      'photos': jsonEncode(church.photos),
      'frissitve': _formatDateTime(church.updatedAt),
      if (church.isGreek != null) 'gorog': church.isGreek! ? 1 : 0,
      ..._searchRow(
        name: church.name,
        commonName: church.commonName,
        alternativeNames: church.alternativeNames,
        city: church.city,
      ),
    };
  }

  ChurchDetails _toChurch(Map<String, Object?> row) {
    return ChurchDetails(
      id: row['id'] as int,
      name: row['nev'] as String?,
      commonName: row['ismertnev'] as String?,
      names: _stringList(row['names']),
      alternativeNames: _stringList(row['alternative_names']),
      country: row['orszag'] as String?,
      diocese: row['egyhazmegye'] as String?,
      county: row['megye'] as String?,
      city: row['varos'] as String?,
      street: row['cim'] as String?,
      gettingThere: row['megkozelites'] as String?,
      parish: row['plebania'] as String?,
      description: row['leiras'] as String?,
      accessibility: _object(row['accessibility']),
      email: row['email'] as String?,
      links: _stringList(row['links']),
      languages: _stringList(row['nyelvek']),
      massScheduleNote: row['miserend_megjegyzes'] as String?,
      adorations: _adorations(row['adoraciok']),
      hasConfession: _boolean(row['gyontatas']),
      communities: _communities(row['kozossegek']),
      lat: row['lat'] as double?,
      lon: row['lon'] as double?,
      photos: _stringList(row['photos']),
      updatedAt: _parseDateTime(row['frissitve'] as String?),
      localSyncedAt: _parseDateTime(row['local_synced_at'] as String?),
      isGreek: _boolean(row['gorog']),
    );
  }

  CachedMass _toMass(Map<String, Object?> row) {
    return CachedMass(
      id: row['id'] as int?,
      apiMassId: row['api_mass_id'] as int?,
      churchId: row['church_id'] as int,
      time: _parseDateTime(row['idopont'] as String?)!,
      info: row['informacio'] as String?,
      source: MassSource.values.byName(row['forras'] as String),
    );
  }

  List<Adoration> _adorations(Object? encoded) {
    final decoded = _list(encoded);
    return decoded.whereType<Map>().map((item) {
      return Adoration(
        start: _parseDateTime(item['kezdete'] as String?),
        end: _parseDateTime(item['vege'] as String?),
        kind: item['fajta'] as String?,
        info: item['info'] as String?,
      );
    }).toList();
  }

  List<Community> _communities(Object? encoded) {
    final decoded = _list(encoded);
    return decoded.whereType<Map>().map((item) {
      return Community(
        name: item['nev'] as String?,
        link: item['link'] as String?,
      );
    }).toList();
  }

  List<String> _stringList(Object? encoded) =>
      _list(encoded).whereType<String>().toList();

  List<dynamic> _list(Object? encoded) {
    if (encoded is! String || encoded.isEmpty) return const [];
    final decoded = jsonDecode(encoded);
    return decoded is List ? decoded : const [];
  }

  Map<String, dynamic>? _object(Object? encoded) {
    if (encoded is! String || encoded.isEmpty) return null;
    final decoded = jsonDecode(encoded);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
  }

  bool? _boolean(Object? value) => value == null ? null : value == 1;

  /// Sorts the same lexicographically as it does chronologically, so range
  /// queries and ordering work on the stored text directly.
  String? _formatDateTime(DateTime? value) {
    if (value == null) return null;
    String pad(int n, [int width = 2]) => n.toString().padLeft(width, '0');
    return '${pad(value.year, 4)}-${pad(value.month)}-${pad(value.day)} '
        '${pad(value.hour)}:${pad(value.minute)}:${pad(value.second)}';
  }

  DateTime? _parseDateTime(String? value) =>
      value == null ? null : DateTime.parse(value);
}
