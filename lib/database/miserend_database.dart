import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:miserend/database/church.dart';
import 'package:miserend/database/mass.dart';
import 'package:miserend/database/church_with_masses.dart';
import 'package:miserend/mass_filter.dart';
import 'package:miserend/preferences.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';


class MiserendDatabase {
  static const String databaseName = "miserend.sqlite3";
  static const massesInnerQuery = '\'[\' || GROUP_CONCAT(\'{'
      '"ido":"\' || m.ido || \'", '
      '"nap":\' || m.nap || \', '
      '"datumtol":\' || m.datumtol || \', '
      '"datumig":\' || m.datumig || \', '
      '"periodus":"\' || m.periodus || \'"'
      '}\', \',\') || \']\' AS misek';

  /// How many days past its download the export still puts masses on the
  /// right day. Its dates carry no year (`HHNN`) and span a 182-day window, so
  /// beyond that a mass would silently land on the wrong day. Only needed
  /// while screens still read the export; remove with them (spec 0005).
  static const int massesValidForDays = 182;

  MiserendDatabase(this.db, {required this.downloadedAt});

  final Database db;

  /// When the export was last downloaded, or null if that was never recorded.
  final DateTime? downloadedAt;

  /// The open connection, shared by every page. The file is written by
  /// [DatabaseManager] on the splash screen before anything queries it, so a
  /// single long-lived instance is safe and saves reopening it per page,
  /// per search keystroke and per map marker tap.
  static Future<MiserendDatabase>? _instance;

  static Future<MiserendDatabase> create() {
    return _instance ??= _open().onError((error, stackTrace) {
      _instance = null;
      throw error!;
    });
  }

  static Future<MiserendDatabase> _open() async {
    final db = await openDatabase(join(await getDatabasesPath(), databaseName));
    await _createIndexes(db);
    final downloaded = await Preferences.getDatabaseLastUpdated();
    return MiserendDatabase(db,
        downloadedAt: downloaded == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(downloaded));
  }

  /// The downloaded file ships without any index, so every join against the
  /// ~280k row mass table made SQLite build a throwaway index first. Creating
  /// them once costs well under a second and is a no-op on later runs; a
  /// re-downloaded database loses them and gets them back here.
  static Future<void> _createIndexes(Database db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_misek_tid ON misek(tid)');
  }

  /// Whether the export is too old to show masses for [day]. Counted in
  /// calendar days, so a daylight saving change cannot move the cut-off. An
  /// unknown download date is treated as too old: a wrong mass time is worse
  /// than none.
  bool massesExpiredOn(DateTime day) {
    final downloaded = downloadedAt;
    if (downloaded == null) return true;
    final age = DateTime.utc(day.year, day.month, day.day)
        .difference(
            DateTime.utc(downloaded.year, downloaded.month, downloaded.day))
        .inDays;
    return age > massesValidForDays;
  }

  Future<List<Church>> getAllChurches() async {
    final List<Map<String, dynamic>> maps = await db.query('templomok');
    return _mapToChurchList(maps);
  }

  Future<List<Church>> getChurchesForSearchTerm(String searchTerm) async {
    String query = 'select * from templomok WHERE nev like \'%${searchTerm}%\' '
        'or ismertnev like \'%${searchTerm}%\'';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query);
    return _mapToChurchList(maps);
  }

  Future<List<String>> getCitiesForSearchTerm(String searchTerm) async {
    String query = 'select distinct varos from templomok WHERE varos like \'%${searchTerm}%\'';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query);
    return  List.generate(maps.length, (i) {
      return maps[i]['varos'];
    });
  }

  Future<List<ChurchWithMasses>> getChurchesWithMassesForSearchTerm(
      String searchTerm, DateTime day) async {
    String query = 'select t.*, ${massesInnerQuery} from templomok as t left join misek as m on ${_massesOn(day)} WHERE t.nev like \'%${searchTerm}%\' '
        'or t.ismertnev like \'%${searchTerm}%\' GROUP BY t.tid';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query);
    return _mapToChurchWithMasses(maps, day);
  }

  Future<List<ChurchWithMasses>> getChurchesWithMassesForCity(
      String city, DateTime day) async {
    String query = 'select t.*, ${massesInnerQuery} from templomok as t left join misek as m on ${_massesOn(day)} WHERE t.varos = \'${city}\' '
        'GROUP BY t.tid';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query);
    return _mapToChurchWithMasses(maps, day);
  }

  Future<List<ChurchWithMasses>> getChurches(
      List<int> churchIds, DateTime day) async {

    String query =
        'select t.*, ${massesInnerQuery} from templomok as t left join misek as m on ${_massesOn(day)} WHERE t.tid IN (${churchIds.join(",")}) GROUP BY t.tid ';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query);
    return _mapToChurchWithMasses(maps, day);

  }

  Future<List<Church>> getCloseChurches(
      double latitude, double longitude) async {
    String query =
        'SELECT *,((lng-($longitude))*(lng-($longitude)) + (lat-($latitude))*(lat-($latitude))) AS len FROM templomok WHERE lng != 0 AND lat != 0 ORDER BY len ASC';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query);
    return _mapToChurchList(maps);
  }

  Future<List<Mass>> getMassesForChurch(
      int churchId) async {
    String query = 'select * from misek where tid = $churchId';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query);
    return _mapToMassList(maps);
  }

  Future<List<ChurchWithMasses>> getCloseChurchesWithMasses(
      double latitude, double longitude, DateTime day) async {

    String query =
        'select t.*, $massesInnerQuery, '
        '((t.lng-($longitude))*(t.lng-($longitude)) + (t.lat-($latitude))*(t.lat-($latitude))) AS len '
        'from templomok as t left join misek as m on ${_massesOn(day)} '
        'WHERE t.lng != 0 AND t.lat != 0 '
        'GROUP BY t.tid '
        'ORDER BY len';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query);

    return _mapToChurchWithMasses(maps, day);
  }

  /// Join condition pairing a church with only the masses it holds on [day].
  /// It belongs in the ON clause, not the WHERE clause, so that churches
  /// without a mass today still appear in the list.
  String _massesOn(DateTime day) =>
      'm.tid = t.tid AND ${MassFilter.sqlForDay(day)}';

  /// Masses come back as one JSON array per church, built by
  /// [massesInnerQuery], and are already narrowed to the requested day.
  List<Mass> _massesFromJson(String? encoded) {
    if (encoded == null) return <Mass>[];
    final List t = json.decode(encoded);
    return t.map((item) => _mapToMass(item)).toList();
  }

  List<ChurchWithMasses> _mapToChurchWithMasses(
      List<Map<String, dynamic>> maps, DateTime day) {
    final expired = massesExpiredOn(day);
    return List.generate(maps.length, (i) {
      return ChurchWithMasses(
          _mapToChurch(maps[i]),
          expired
              ? <Mass>[]
              : _massesFromJson(maps[i]['misek'] as String?),
          massesExpired: expired);
    });
  }

  List<Church> _mapToChurchList(List<Map<String, dynamic>> maps) {
    return List.generate(maps.length, (i) {
      return _mapToChurch(maps[i]);
    });
  }

  Church _mapToChurch(Map<String, dynamic> map) {
    return Church(
        id: map['tid'],
        name: map['nev'],
        commonName: map['ismertnev'],
        isGreek: map['gorog'] == 1,
        lat: map['lat'],
        lon: map['lng'],
        address: map['geocim'],
        city: map['varos'],
        country: map['orszag'],
        county: map['megye'],
        street: map['cim'],
        gettingThere: map['megkozelites'],
        imageUrl: map['kep']);
  }

  List<Mass> _mapToMassList(List<Map<String, dynamic>> maps) {
    return List.generate(maps.length, (i) {
      return _mapToMass(maps[i]);
    });
  }

  Mass _mapToMass(Map<String, dynamic> map) {
    String s = map['ido'];
    TimeOfDay timeOfDay = TimeOfDay(hour:int.parse(s.split(":")[0]),minute: int.parse(s.split(":")[1]));
    return Mass(
      id: map['mid'],
      churchId: map['tid'],
      day: map['nap'],
      time: timeOfDay,
      season: map['idoszak'],
      language: map['nyelv'],
      tags: map['milyen'],
      period: map['periodus'],
      weight: map['suly'],
      startDate: map['datumtol'],
      endDate: map['datumig'],
      comment: map['megjegyzes'],
    );
  }
}
