import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:miserend/database/church.dart';
import 'package:miserend/database/mass.dart';
import 'package:miserend/database/mass_with_church.dart';
import 'package:miserend/database/church_with_masses.dart';
import 'package:miserend/mass_filter.dart';
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

  late Database db;

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
    MiserendDatabase instance = MiserendDatabase();
    await instance.openDb();
    return instance;
  }

  Future<void> openDb() async {
    db = await openDatabase(join(await getDatabasesPath(), databaseName));
    await _createIndexes();
  }

  /// The downloaded file ships without any index, so every join against the
  /// ~280k row mass table made SQLite build a throwaway index first. Creating
  /// them once costs well under a second and is a no-op on later runs; a
  /// re-downloaded database loses them and gets them back here.
  Future<void> _createIndexes() async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_misek_tid ON misek(tid)');
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
    return _mapToChurchWithMasses(maps);
  }

  Future<List<ChurchWithMasses>> getChurchesWithMassesForCity(
      String city, DateTime day) async {
    String query = 'select t.*, ${massesInnerQuery} from templomok as t left join misek as m on ${_massesOn(day)} WHERE t.varos = \'${city}\' '
        'GROUP BY t.tid';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query);
    return _mapToChurchWithMasses(maps);
  }

  Future<List<ChurchWithMasses>> getChurches(
      List<int> churchIds, DateTime day) async {

    String query =
        'select t.*, ${massesInnerQuery} from templomok as t left join misek as m on ${_massesOn(day)} WHERE t.tid IN (${churchIds.join(",")}) GROUP BY t.tid ';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query);
    return _mapToChurchWithMasses(maps);

  }

  Future<List<Church>> getCloseChurches(
      double latitude, double longitude) async {
    String query =
        'SELECT *,((lng-($longitude))*(lng-($longitude)) + (lat-($latitude))*(lat-($latitude))) AS len FROM templomok WHERE lng != 0 AND lat != 0 ORDER BY len ASC';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query);
    return _mapToChurchList(maps);
  }

  /// The 500 nearest masses held on [day]. The day filter has to run before
  /// the limit, otherwise the limit is spent on masses that are not held
  /// today and the page ends up nearly empty.
  Future<List<MassWithChurch>> getCloseMasses(
      double latitude, double longitude, DateTime day) async {
    String query =
        'select *,((templomok.lng-($longitude))*(templomok.lng-($longitude)) + (templomok.lat-($latitude))*(templomok.lat-($latitude))) AS len from misek inner join templomok on misek.tid = templomok.tid WHERE templomok.lng != 0 AND templomok.lat != 0 AND ${MassFilter.sqlForDay(day, alias: "misek")} ORDER BY len ASC LIMIT 500';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query);
    return List.generate(maps.length, (i) {
      return MassWithChurch(_mapToChurch(maps[i]), _mapToMass(maps[i]));
    });
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

    return _mapToChurchWithMasses(maps);
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

  List<ChurchWithMasses> _mapToChurchWithMasses(List<Map<String, dynamic>> maps) {
    return List.generate(maps.length, (i) {
      return ChurchWithMasses(
          _mapToChurch(maps[i]), _massesFromJson(maps[i]['misek'] as String?));
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
