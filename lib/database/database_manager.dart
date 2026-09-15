import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../preferences.dart';

class DatabaseManager
{
  static final String _databaseFileName = 'miserend.sqlite3';
  static final int _databaseVersion = 4;

  /// The documented export endpoint. It redirects to the file itself, whose
  /// name is not part of the API and may change.
  static final String _exportUrl = 'https://miserend.hu/api/v4/sqlite';

  /// How long connecting, and then each wait for the next chunk of the file,
  /// may take. Without it a connection that stops answering would keep the
  /// splash screen spinning instead of reporting the failure. It bounds the
  /// silence, not the whole download, so a slow network still gets through.
  static const Duration _timeout = Duration(seconds: 30);

   static Future<String> get databaseFilePath async {
    return join(await getDatabasesPath(), _databaseFileName);
  }

  static Future<bool> get databaseExists async
  {
    return await File(await databaseFilePath).exists();
  }

  static Future<bool> checkDatabaseVersion() async
  {
    var savedVersion = await Preferences.getDatabaseVersion();
    return savedVersion == _databaseVersion;
  }

  /// Downloads the export, which only feeds the one-time cache import and the
  /// screens not yet moved to the API. It is fetched when missing or of the
  /// wrong version, never to refresh it (ADR-0003).
  static Future<bool> downloadDatabase() async
  {
    return _downloadFile(
        _exportUrl, _databaseFileName, await getDatabasesPath());
  }

   static Future<bool> _downloadFile(String url, String fileName, String dir) async {
     HttpClient httpClient = HttpClient()..connectionTimeout = _timeout;
     File file;
     try {
       // GET requests follow the endpoint's redirect by default.
       var request = await httpClient.getUrl(Uri.parse(url));
       var response = await request.close().timeout(_timeout);
       if(response.statusCode == 200) {
         var bytes = await response
             .timeout(_timeout)
             .fold(BytesBuilder(copy: false), (builder, chunk) => builder..add(chunk))
             .then((builder) => builder.takeBytes());
         var filePath = '$dir/$fileName';
         file = File(filePath);
         await file.writeAsBytes(bytes);
         await Preferences.setDatabaseVersion(_databaseVersion);
         await Preferences.setDatabaseLastUpdated(DateTime.now().millisecondsSinceEpoch);
         return true;
       }
       else {
         return false;
       }
     }
     catch(ex){
       return false;
     }
     finally {
       httpClient.close();
     }
   }
}
