import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/testing.dart';
import 'package:miserend/bootstrap/cache_bootstrap.dart';

/// Answers the size with [size] and runs only as far as the test drives it,
/// through [report] and [end]. What it is told is kept across pumps, as an
/// app's stored flags are across starts.
class FakeCacheBootstrap extends CacheBootstrap {
  FakeCacheBootstrap({this.size, bool done = false, bool declined = false})
    : doneFlag = ValueNotifier(done),
      _declinedFlag = declined,
      super(
        client: MockClient(
          (_) async => throw StateError('no request leaves a fake'),
        ),
      );

  /// What [exportSize] answers; null is no answer in time.
  int? size;

  /// Completes [exportSize] when given, so a test can hold it.
  Completer<void>? sizeHeld;

  final ValueNotifier<bool> doneFlag;
  bool _declinedFlag;

  int sizeQueries = 0;
  int runs = 0;
  int cancels = 0;

  StreamController<BootstrapProgress>? _run;

  @override
  ValueListenable<bool> get done => doneFlag;

  @override
  bool get declined => _declinedFlag;

  @override
  Future<void> restore() async {}

  @override
  Future<void> decline() async => _declinedFlag = true;

  @override
  Future<int?> exportSize() async {
    sizeQueries++;
    await sizeHeld?.future;
    return size;
  }

  @override
  Stream<BootstrapProgress> run() {
    runs++;
    return (_run = StreamController()).stream;
  }

  @override
  void cancel() => cancels++;

  /// Reports [progress] from the run going on.
  void report(BootstrapProgress progress) => _run!.add(progress);

  /// Ends the run going on with [progress], with what a real run does to the
  /// flags.
  Future<void> end(BootstrapProgress progress) async {
    switch (progress) {
      case BootstrapDone():
        doneFlag.value = true;
      case BootstrapCancelled():
        _declinedFlag = true;
      case BootstrapDownloading():
      case BootstrapImporting():
      case BootstrapFailed():
        break;
    }
    _run!.add(progress);
    await _run!.close();
  }
}
