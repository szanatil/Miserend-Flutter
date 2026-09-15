import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:miserend/database/cache/bootstrap_importer.dart';
import 'package:miserend/database/cache/cache_database.dart';
import 'package:miserend/database/database_manager.dart';
import 'package:miserend/database/miserend_database.dart';
import 'package:miserend/home/home.dart';
import 'package:miserend/preferences.dart';

/// What the splash screen does to get the app ready, behind one seam so that
/// the screen can be pumped without files, preferences or a network.
class AppStartup {
  const AppStartup();

  Future<bool> exportExists() => DatabaseManager.databaseExists;

  Future<bool> exportVersionCompatible() =>
      DatabaseManager.checkDatabaseVersion();

  Future<bool> downloadExport() => DatabaseManager.downloadDatabase();

  Future<bool> isCacheBootstrapped() => Preferences.isCacheBootstrapped();

  /// The one-time import of the export into the cache. Throws when it fails.
  Future<void> bootstrapCache() async {
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
  }
}

class RouteSplash extends StatefulWidget {
  const RouteSplash({
    super.key,
    this.startup = const AppStartup(),
    this.homeBuilder = _home,
  });

  /// Injected by tests.
  final AppStartup startup;
  final WidgetBuilder homeBuilder;

  static Widget _home(BuildContext context) => const HomeScreen();

  @override
  State<RouteSplash> createState() => _RouteSplashState();
}

class _RouteSplashState extends State<RouteSplash> {
  bool shouldProceed = false;

  /// Shown under the spinner while the one-time cache import runs, which takes
  /// long enough to look like a hang without it.
  String? _status;

  /// Set when the export could not be downloaded and there is no earlier copy
  /// to fall back on, so the app has nothing to show until a retry succeeds.
  bool _downloadFailed = false;

  /// Set when the first import into the cache failed. Every screen reads the
  /// cache, so going on would show nothing but empty lists.
  bool _bootstrapFailed = false;

  _checkDatabase() async {
    final bool fileExists = await widget.startup.exportExists();
    if (!fileExists) {
      unawaited(
        _showDialog(
          'Adatabázis nem taláható',
          'Az alkalmazás használatához szükség van az adatbázis letöltésére. Letölti most?',
        ),
      );
      return;
    }

    final bool databaseVersionCompatible =
        await widget.startup.exportVersionCompatible();
    if (!databaseVersionCompatible) {
      unawaited(
        _showDialog(
          'Adatbázis nem megfelelő',
          'Az alkalmazás használatához szükség van az adatbázis letöltésére. Letölti most?',
        ),
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
    final bool success = await widget.startup.downloadExport();
    if (success) {
      if (mounted) {
        const snackBar = SnackBar(content: Text('Adatbázis letöltése sikeres'));
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }
      _goToMainScreen();
      return;
    }

    // An earlier export, even of the wrong version, beats keeping the user
    // out of the app; once the cache has been filled no screen reads it.
    if (await widget.startup.exportExists()) {
      if (mounted) {
        const snackBar = SnackBar(
          content: Text(
            'Az adatbázis letöltése nem sikerült, '
            'a korábban letöltött adatokkal folytatjuk.',
          ),
        );
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
    if (!await _bootstrapCacheIfNeeded()) {
      return;
    }
    if (!mounted) {
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: widget.homeBuilder),
    );
  }

  /// The cache starts out empty and every screen reads it, so it is filled
  /// once from the downloaded export before the home screen opens. False
  /// when that failed: the splash then offers a retry, and the import runs
  /// again on the next start as well.
  Future<bool> _bootstrapCacheIfNeeded() async {
    if (await widget.startup.isCacheBootstrapped()) {
      return true;
    }

    setState(() {
      _bootstrapFailed = false;
      _status = 'Adatok előkészítése…';
    });
    try {
      await widget.startup.bootstrapCache();
      return true;
    } catch (error) {
      debugPrint('Cache bootstrap failed: $error');
      if (mounted) {
        setState(() {
          _status = null;
          _bootstrapFailed = true;
        });
      }
      return false;
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
      return _retryScreen(
        'Az adatbázis letöltése nem sikerült. Ellenőrizd az '
        'internetkapcsolatot, és próbáld újra.',
        _downloadDatabase,
      );
    }
    if (_bootstrapFailed) {
      return _retryScreen(
        'Az adatok előkészítése nem sikerült. Próbáld újra.',
        _goToMainScreen,
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

  Widget _retryScreen(String message, VoidCallback onRetry) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Újrapróbálás'),
              ),
            ],
          ),
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
