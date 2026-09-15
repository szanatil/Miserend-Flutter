import 'dart:convert';
import 'dart:math';

import 'package:miserend/database/cache/adoration.dart';
import 'package:miserend/database/cache/cached_mass.dart';
import 'package:miserend/database/cache/church_details.dart';
import 'package:miserend/database/cache/church_list_entry.dart';
import 'package:miserend/database/cache/community.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// The write-through cache behind the v4 API. It is a separate file from the
/// downloaded `miserend.sqlite3`, which stays read-only and keeps serving the
/// screens that have not moved to the API yet.
class CacheDatabase {
  static const String databaseName = "miserend_cache.sqlite3";

  static const String churchesTable = "churches_cache";
  static const String massesTable = "masses_cache";
  static const String syncTable = "sync_state";

  late Database db;

  /// [path] exists for tests, which open an in-memory database.
  static Future<CacheDatabase> create({String? path}) async {
    CacheDatabase instance = CacheDatabase();
    await instance.openDb(path ?? join(await getDatabasesPath(), databaseName));
    return instance;
  }

  Future<void> openDb(String path) async {
    db = await openDatabase(
      path,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE $churchesTable('
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
            'gorog INTEGER)');
        await db.execute('CREATE TABLE $massesTable('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'api_mass_id INTEGER, '
            'church_id INTEGER NOT NULL, '
            'idopont TEXT NOT NULL, '
            'informacio TEXT, '
            'forras TEXT NOT NULL)');
        await db.execute('CREATE INDEX idx_masses_cache_church_time '
            'ON $massesTable(church_id, idopont)');
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
              "ALTER TABLE $massesTable ADD COLUMN forras TEXT NOT NULL "
              "DEFAULT '${MassSource.bootstrap.name}'");
          await db.execute("UPDATE $massesTable SET forras = "
              "'${MassSource.nearbyMasses.name}' WHERE api_mass_id IS NOT NULL");
        }
      },
      version: 3,
    );
  }

  /// When things happened to the cache as a whole, as opposed to one church:
  /// the bootstrap import, a list's last successful refresh.
  static Future<void> _createSyncTable(Database db) => db.execute(
      'CREATE TABLE $syncTable(kulcs TEXT PRIMARY KEY, idopont TEXT NOT NULL)');

  static const String _bootstrapKey = 'bootstrap';

  /// When the bootstrap import filled the cache, or null if that was never
  /// recorded. It is how old the data is on a row no API response has touched.
  Future<DateTime?> bootstrappedAt() => syncTime(_bootstrapKey);

  Future<void> setBootstrappedAt(DateTime time) =>
      setSyncTime(_bootstrapKey, time);

  Future<DateTime?> syncTime(String key) async {
    final rows = await db.query(syncTable,
        where: 'kulcs = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return _parseDateTime(rows.first['idopont'] as String?);
  }

  Future<void> setSyncTime(String key, DateTime time) async {
    await db.insert(
      syncTable,
      {'kulcs': key, 'idopont': _formatDateTime(time)},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<ChurchDetails?> getChurch(int id) async {
    final rows = await db.query(churchesTable, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _toChurch(rows.first);
  }

  /// The columns a `minimal` API response carries. The others — photos,
  /// description, names, address and the rest — are absent from it, not
  /// empty, so they must not overwrite what the cache already holds.
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
  };

  /// Writes an API response over the cached row. A column the API does not
  /// carry — `gorog` — keeps whatever the bootstrap import put there, and so
  /// do the columns a [minimal] response leaves out.
  Future<void> upsertChurch(ChurchDetails church,
      {bool minimal = false}) async {
    final row = _toRow(church);
    if (minimal) row.removeWhere((column, _) => !_minimalColumns.contains(column));
    final values = {
      ...row,
      'local_synced_at': _formatDateTime(DateTime.now()),
    };
    final updated = await db.update(churchesTable, values,
        where: 'id = ?', whereArgs: [church.id]);
    if (updated == 0) {
      await db.insert(churchesTable, {...values, 'id': church.id});
    }
  }

  /// The bootstrap import's bulk write: one transaction for the whole chunk,
  /// because doing this a row at a time costs a transaction per church and the
  /// import covers every church the app knows. It writes no
  /// `local_synced_at` — these rows have never seen an API response.
  Future<void> importChurches(
      List<ChurchDetails> churches, List<CachedMass> masses) async {
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final church in churches) {
        batch.insert(churchesTable, {..._toRow(church), 'id': church.id},
            conflictAlgorithm: ConflictAlgorithm.replace);
        batch.delete(massesTable,
            where: 'church_id = ?', whereArgs: [church.id]);
      }
      for (final mass in masses) {
        batch.insert(massesTable, _massRow(mass));
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> replaceMassesForChurch(
      int churchId, List<CachedMass> masses) async {
    final batch = db.batch();
    batch.delete(massesTable, where: 'church_id = ?', whereArgs: [churchId]);
    for (final mass in masses) {
      batch.insert(massesTable, _massRow(mass));
    }
    await batch.commit(noResult: true);
  }

  /// Puts a list answer's rows for [day] in place of the day's cached rows —
  /// unless the details page's schedule already covers the day, which is the
  /// more precise source and is left as it is.
  Future<void> replaceDailyMasses(
      int churchId, DateTime day, List<CachedMass> masses) async {
    final (from, until) = _dayBounds(day);
    await db.transaction((txn) async {
      final detailed = await txn.query(
        massesTable,
        columns: ['id'],
        where: 'church_id = ? AND idopont >= ? AND idopont < ? AND forras = ?',
        whereArgs: [churchId, from, until, MassSource.nearbyMasses.name],
        limit: 1,
      );
      if (detailed.isNotEmpty) return;

      final batch = txn.batch();
      batch.delete(massesTable,
          where: 'church_id = ? AND idopont >= ? AND idopont < ?',
          whereArgs: [churchId, from, until]);
      for (final mass in masses) {
        batch.insert(massesTable, _massRow(mass));
      }
      await batch.commit(noResult: true);
    });
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

  Future<List<CachedMass>> getMassesForChurch(int churchId,
      {DateTime? from, DateTime? until}) async {
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

    final rows = await db.query(massesTable,
        where: where.toString(), whereArgs: args, orderBy: 'idopont');
    return rows.map(_toMass).toList();
  }

  /// Every church with a position, nearest to ([lat], [lon]) first, with its
  /// rows of [day]. Unbounded: the list shows them all.
  Future<List<ChurchListEntry>> nearChurches(
      double lat, double lon, DateTime day) async {
    // Degrees of longitude shrink towards the poles; scaling them keeps the
    // order right without trigonometry in SQL.
    final lonScale = cos(lat * pi / 180);
    final rows = await db.rawQuery(
      'SELECT $_listColumns FROM $churchesTable '
      'WHERE lat IS NOT NULL AND lon IS NOT NULL AND NOT (lat = 0 AND lon = 0) '
      'ORDER BY (lat - ?) * (lat - ?) + '
      '(lon - ?) * (lon - ?) * ? * ?, id',
      [lat, lat, lon, lon, lonScale, lonScale],
    );
    return _listEntries(rows, day);
  }

  static const String _listColumns = 'id, nev, ismertnev, varos, lat, lon, photos';

  Future<List<ChurchListEntry>> _listEntries(
      List<Map<String, Object?>> rows, DateTime day) async {
    final masses = await _massesOn(day);
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

  /// Every cached row of [day], by church. One query for the whole list
  /// rather than one per church.
  Future<Map<int, List<CachedMass>>> _massesOn(DateTime day) async {
    final (from, until) = _dayBounds(day);
    final rows = await db.query(
      massesTable,
      where: 'idopont >= ? AND idopont < ?',
      whereArgs: [from, until],
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
      'accessibility': church.accessibility == null
          ? null
          : jsonEncode(church.accessibility),
      'email': church.email,
      'links': jsonEncode(church.links),
      'nyelvek': jsonEncode(church.languages),
      'miserend_megjegyzes': church.massScheduleNote,
      'adoraciok': jsonEncode(church.adorations
          .map((a) => {
                'kezdete': _formatDateTime(a.start),
                'vege': _formatDateTime(a.end),
                'fajta': a.kind,
                'info': a.info,
              })
          .toList()),
      'gyontatas': church.hasConfession == null
          ? null
          : (church.hasConfession! ? 1 : 0),
      'kozossegek': jsonEncode(church.communities
          .map((c) => {'nev': c.name, 'link': c.link})
          .toList()),
      'lat': church.lat,
      'lon': church.lon,
      'photos': jsonEncode(church.photos),
      'frissitve': _formatDateTime(church.updatedAt),
      if (church.isGreek != null) 'gorog': church.isGreek! ? 1 : 0,
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
          name: item['nev'] as String?, link: item['link'] as String?);
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
