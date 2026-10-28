import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:miserend/database/cache/bootstrap_importer.dart';
import 'package:miserend/database/cache/cache_database.dart';
import 'package:miserend/preferences.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// How far a [CacheBootstrap.run] has got. The first two come any number of
/// times; one of the last three ends the run.
sealed class BootstrapProgress {
  const BootstrapProgress();
}

/// The export is on its way: [received] bytes of [total], which is null when
/// the server did not say.
final class BootstrapDownloading extends BootstrapProgress {
  const BootstrapDownloading(this.received, this.total);

  final int received;
  final int? total;
}

/// The export is in, and its rows are going into the cache.
final class BootstrapImporting extends BootstrapProgress {
  const BootstrapImporting();
}

/// The cache holds the export's rows: the bootstrap import is never offered
/// again.
final class BootstrapDone extends BootstrapProgress {
  const BootstrapDone();
}

/// The download or the import went wrong. The user did not turn the
/// bootstrap import down, so it is offered again on the next start.
final class BootstrapFailed extends BootstrapProgress {
  const BootstrapFailed();
}

/// The user stopped the download, which counts as turning it down.
final class BootstrapCancelled extends BootstrapProgress {
  const BootstrapCancelled();
}

/// The **kezdeti feltöltés** (CONTEXT.md) as a whole: whether it is worth
/// offering, how large it is, and running it — the SQLite export downloaded,
/// imported to fill the cache's gaps, and deleted (ADR-0006, spec 0015).
class CacheBootstrap {
  CacheBootstrap({
    http.Client? client,
    CacheDatabase? cache,
    Future<String> Function()? directory,
    this.clock = DateTime.now,
  }) : _client = client ?? IOClient(HttpClient()),
       _cache = cache,
       _directory = directory ?? getDatabasesPath;

  /// The app's: the splash, the Névjegy and the screens that read the cache
  /// alone share what it knows.
  static final CacheBootstrap shared = CacheBootstrap();

  /// The documented export endpoint. It redirects to the file itself, whose
  /// name is not part of the API and may change.
  static final Uri exportUrl = Uri.parse('https://miserend.hu/api/v4/sqlite');

  /// How long the size may take to come back, redirects included. The splash
  /// waits for it, and no answer by then counts as offline: a weak signal must
  /// not hold the app back for long (spec 0015, user story 16).
  static const Duration sizeTimeout = Duration(seconds: 5);

  /// How long connecting, and then each wait for the next chunk of the file,
  /// may take. It bounds the silence, not the whole download, so a slow
  /// network still gets through, and a connection that stops answering ends
  /// in a failure rather than a bar that never moves.
  static const Duration silenceTimeout = Duration(seconds: 30);

  /// More hops than the endpoint's one redirect is a loop.
  static const int _maxRedirects = 5;

  /// The download's name on the phone; the export's earlier copies, from
  /// before ADR-0006, lie under the same name.
  static const String _fileName = 'miserend.sqlite3';

  final http.Client _client;
  CacheDatabase? _cache;
  final Future<String> Function() _directory;
  final DateTime Function() clock;

  /// Whether a bootstrap import has ever succeeded. From then on it is never
  /// offered again, and the screens stop saying it may be missing.
  ValueListenable<bool> get done => _done;
  final ValueNotifier<bool> _done = ValueNotifier(false);

  /// Whether the user turned the bootstrap import down: the splash does not
  /// offer it again. Only „Most nem" and stopping the download set it.
  bool get declined => _declined;
  bool _declined = false;

  /// Completed by [cancel]; null while no download runs.
  Completer<void>? _cancel;

  /// Reads what earlier starts stored, before anything asks [done] or
  /// [declined], and deletes an export left behind: no run is going on yet.
  Future<void> restore() async {
    _done.value = await Preferences.isCacheBootstrapped();
    _declined = await Preferences.isBootstrapDeclined();
    await _delete(await _file());
  }

  /// „Most nem".
  Future<void> decline() async {
    _declined = true;
    await Preferences.setBootstrapDeclined();
  }

  /// The export's size in bytes, or null when it did not come back within
  /// [sizeTimeout] — which is also how the app tells it is offline.
  Future<int?> exportSize() async {
    try {
      final response = await _send('HEAD').timeout(sizeTimeout);
      if (response.statusCode != HttpStatus.ok) return null;
      return int.tryParse(response.headers['content-length'] ?? '');
    } catch (error) {
      // Nothing to retry: without an answer the app starts without the offer.
      debugPrint('Export size unavailable: ${error.runtimeType}');
      return null;
    }
  }

  /// Downloads the export and imports it, from the start every time: a run
  /// cut short is not picked up again, since the import only fills gaps and
  /// so ends up where a whole run would (ADR-0006). The file is deleted
  /// however the run ends.
  Stream<BootstrapProgress> run() {
    final progress = StreamController<BootstrapProgress>();
    unawaited(
      _run(progress.add).then((end) {
        progress.add(end);
        return progress.close();
      }),
    );
    return progress.stream;
  }

  /// Stops the download; once the import has begun it runs to its end.
  void cancel() {
    final cancel = _cancel;
    if (cancel != null && !cancel.isCompleted) cancel.complete();
  }

  Future<BootstrapProgress> _run(
    void Function(BootstrapProgress) report,
  ) async {
    final cancel = _cancel = Completer<void>();
    final file = await _file();
    try {
      if (!await _download(file, cancel.future, report)) {
        await decline();
        return const BootstrapCancelled();
      }
      _cancel = null;
      report(const BootstrapImporting());
      await _import(file);
      await Preferences.setCacheBootstrapped();
      _done.value = true;
      return const BootstrapDone();
    } catch (error) {
      // Whatever broke, the run has to end with an answer the progress screen
      // can show; the user is offered it again on the next start.
      debugPrint('Bootstrap import failed: ${error.runtimeType}');
      return const BootstrapFailed();
    } finally {
      _cancel = null;
      await _delete(file);
    }
  }

  /// Writes the export to [file]; false when [cancelled] came first.
  Future<bool> _download(
    File file,
    Future<void> cancelled,
    void Function(BootstrapProgress) report,
  ) async {
    final response = await Future.any<http.StreamedResponse?>([
      _send('GET').timeout(silenceTimeout),
      cancelled.then((_) => null),
    ]);
    if (response == null) return false;
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Export answered ${response.statusCode}');
    }

    final total = response.contentLength;
    final sink = file.openWrite();
    var received = 0;
    final finished = Completer<bool>();
    final subscription = response.stream
        .timeout(silenceTimeout)
        .listen(
          (chunk) {
            sink.add(chunk);
            received += chunk.length;
            report(BootstrapDownloading(received, total));
          },
          onError: finished.completeError,
          onDone: () => finished.complete(true),
          cancelOnError: true,
        );
    try {
      return await Future.any([finished.future, cancelled.then((_) => false)]);
    } finally {
      await subscription.cancel();
      await sink.close();
    }
  }

  Future<void> _import(File file) async {
    final legacy = await openDatabase(file.path);
    try {
      await BootstrapImporter.run(
        legacy: legacy,
        cache: _cache ??= await CacheDatabase.create(),
        from: clock(),
        clock: clock,
      );
    } finally {
      await legacy.close();
    }
  }

  /// Asks for the export, following its redirects by hand: the client follows
  /// none of a HEAD request's, and so the size is that of the file itself.
  Future<http.StreamedResponse> _send(String method) async {
    var url = exportUrl;
    for (var hop = 0; ; hop++) {
      final response = await _client.send(
        http.Request(method, url)..followRedirects = false,
      );
      final location = response.headers['location'];
      if (!_redirects(response.statusCode) || location == null) {
        return response;
      }
      if (hop == _maxRedirects) throw const HttpException('Too many redirects');
      unawaited(response.stream.listen(null).cancel());
      url = url.resolve(location);
    }
  }

  static bool _redirects(int status) => const {
    HttpStatus.movedPermanently,
    HttpStatus.found,
    HttpStatus.seeOther,
    HttpStatus.temporaryRedirect,
    HttpStatus.permanentRedirect,
  }.contains(status);

  Future<File> _file() async => File(join(await _directory(), _fileName));

  static Future<void> _delete(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException catch (error) {
      // Left for the next start's [restore] to try again.
      debugPrint('Export not deleted: ${error.runtimeType}');
    }
  }
}
