import 'package:miserend/preferences.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// The downloaded SQLite export. Since spec 0005 its only reader is the
/// one-time bootstrap import; every screen reads the cache instead.
class MiserendDatabase {
  static const String databaseName = "miserend.sqlite3";

  /// How many days past its download the export still puts masses on the
  /// right day. Its dates carry no year (`HHNN`) and span a 182-day window, so
  /// beyond that a mass would silently land on the wrong day, and the
  /// bootstrap import takes the churches alone.
  static const int massesValidForDays = 182;

  MiserendDatabase(this.db, {required this.downloadedAt});

  final Database db;

  /// When the export was last downloaded, or null if that was never recorded.
  final DateTime? downloadedAt;

  /// The open connection. The file is written by [DatabaseManager] on the
  /// splash screen before the bootstrap import reads it.
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

  /// The downloaded file ships without any index, so the bootstrap import's
  /// per-chunk read of the ~280k row mass table would scan it whole. Creating
  /// the index once costs well under a second and is a no-op on later runs; a
  /// re-downloaded database loses it and gets it back here.
  static Future<void> _createIndexes(Database db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_misek_tid ON misek(tid)');
  }

  /// Whether the export is too old to put masses on the right day for [day]. Counted in
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
}
