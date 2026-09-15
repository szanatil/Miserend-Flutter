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

  /// Set when the export could not be downloaded and there is no earlier copy
  /// to fall back on, so the app has nothing to show until a retry succeeds.
  bool _downloadFailed = false;

  _checkDatabase() async {
    bool fileExists = await DatabaseManager.databaseExists;
    if (!fileExists) {
      _showDialog(
        "Adatabázis nem taláható",
        "Az alkalmazás használatához szükség van az adatbázis letöltésére. Letölti most?",
      );
      return;
    }

    bool databaseVersionCompatible =
        await DatabaseManager.checkDatabaseVersion();
    if (!databaseVersionCompatible) {
      _showDialog(
        "Adatbázis nem megfelelő",
        "Az alkalmazás használatához szükség van az adatbázis letöltésére. Letölti most?",
      );
      return;
    }

    _goToMainScreen();
  }

  _downloadDatabase() async {
    setState(() {
      _downloadFailed = false;
      _status = 'Adatbázis letöltése…';
    });
    bool success = await DatabaseManager.downloadDatabase();
    if (success) {
      if (mounted) {
        const snackBar = SnackBar(content: Text('Adatbázis letöltése sikeres'));
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }
      _goToMainScreen();
      return;
    }

    // An earlier export, even of the wrong version, beats keeping the user
    // out of the app; the screens moved to the API do not need it anyway.
    if (await DatabaseManager.databaseExists) {
      if (mounted) {
        const snackBar = SnackBar(
            content: Text('Az adatbázis letöltése nem sikerült, '
                'a korábban letöltött adatokkal folytatjuk.'));
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }
      _goToMainScreen();
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _status = null;
      _downloadFailed = true;
    });
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
      final now = DateTime.now();
      await BootstrapImporter.run(
        legacy: legacy.db,
        cache: cache,
        from: now,
        // An old export only gets here after a failed download or import. Its
        // masses would land on the wrong days, so take the churches alone.
        days: legacy.massesExpiredOn(now) ? 0 : BootstrapImporter.defaultDays,
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
    if (_downloadFailed) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Az adatbázis letöltése nem sikerült. Ellenőrizd az '
                  'internetkapcsolatot, és próbáld újra.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _downloadDatabase,
                  child: const Text('Újrapróbálás'),
                ),
              ],
            ),
          ),
        ),
      );
    }

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

  Future<void> _showDialog(String title, String description) async {
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
                SystemNavigator.pop();
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
