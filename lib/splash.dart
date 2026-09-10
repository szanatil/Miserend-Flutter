import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:miserend/database/cache/bootstrap_importer.dart';
import 'package:miserend/database/cache/cache_database.dart';
import 'package:miserend/database/database_manager.dart';
import 'package:miserend/database/miserend_database.dart';
import 'package:miserend/home/home.dart';
import 'package:miserend/preferences.dart';

class RouteSplash extends StatefulWidget {
  const RouteSplash({super.key});

  @override
  _RouteSplashState createState() => _RouteSplashState();
}

class _RouteSplashState extends State<RouteSplash> {
  bool shouldProceed = false;

  /// Shown under the spinner while the one-time cache import runs, which takes
  /// long enough to look like a hang without it.
  String? _status;

  _checkDatabase() async {
    bool fileExists = await DatabaseManager.databaseExists;
    if (!fileExists) {
      _showDialog(
        "Adatabázis nem taláható",
        "Az alkalmazás használatához szükség van az adatbázis letöltésére. Letölti most?",
        true,
      );
      return;
    }

    bool databaseVersionCompatible =
        await DatabaseManager.checkDatabaseVersion();
    if (!databaseVersionCompatible) {
      _showDialog(
        "Adatbázis nem megfelelő",
        "Az alkalmazás használatához szükség van az adatbázis letöltésére. Letölti most?",
        true,
      );
      return;
    }

    bool isDatabaseUpToDate = await DatabaseManager.isDatabaseUpToDate();
    if (!isDatabaseUpToDate) {
      _showDialog(
        "Frissítés elérhető",
        "Elérhető frisebb adatbázis. Letölti most?",
        false,
      );
      return;
    }

    _goToMainScreen();
  }

  _downloadDatabase() async {
    bool success = await DatabaseManager.downloadDatabase();
    if (success) {
      if (context.mounted) {
        const snackBar = SnackBar(content: Text('Adatbázis frissítés sikeres'));
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }
      _goToMainScreen();
    } else {
      if (context.mounted) {
        const snackBar = SnackBar(content: Text('Adatbázis frissítése sikertelen'));
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }
    }
  }

  _goToMainScreen() async {
    await _bootstrapCacheIfNeeded();
    if (!mounted) {
      return;
    }
    Navigator.pushReplacement(
      this.context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  /// The API-backed cache starts out empty. It is filled once from the
  /// downloaded database so that the church details page has something to show
  /// before its first API call — and still has it when the phone is offline.
  Future<void> _bootstrapCacheIfNeeded() async {
    if (await Preferences.isCacheBootstrapped()) {
      return;
    }

    setState(() => _status = 'Adatok előkészítése…');
    try {
      final legacy = await MiserendDatabase.create();
      final cache = await CacheDatabase.create();
      await BootstrapImporter.run(
        legacy: legacy.db,
        cache: cache,
        from: DateTime.now(),
      );
      await Preferences.setCacheBootstrapped();
    } catch (error) {
      // Every screen still reads the downloaded database, so a failed import
      // must not keep the user out of the app. The details page will fill the
      // cache from the API instead, one church at a time.
      debugPrint('Cache bootstrap failed: $error');
    }
  }

  @override
  void initState() {
    super.initState();
    _checkDatabase(); //running initialisation code; getting prefs etc.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            if (_status != null) ...[
              const SizedBox(height: 16),
              Text(_status!),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showDialog(
    String title,
    String description,
    bool forced,
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(description),
          actions: <Widget>[
            TextButton(
              child: const Text('Nem'),
              onPressed: () {
                if (forced) {
                  SystemNavigator.pop();
                } else {
                  Navigator.of(context).pop();
                  _goToMainScreen();
                }
              },
            ),
            TextButton(
              child: const Text('Igen'),
              onPressed: () {
                Navigator.of(context).pop();
                _downloadDatabase();
              },
            ),
          ],
        );
      },
    );
  }
}
