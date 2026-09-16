import 'dart:async';

import 'package:flutter/material.dart';

/// Asks the screen to try again, on its own, while stale data is on screen.
///
/// The screens fetch once and keep whatever came back, so a screen opened
/// without a connection used to stay stale until the user pulled the list down
/// or opened the church again — even after the phone was back online. The way
/// out is not to watch the network: the app cannot tell the four causes of
/// **Nincs kapcsolat** apart (CONTEXT.md), and a phone reporting Wi-Fi may
/// still have no route to miserend.hu, or no permission to take it. It simply
/// tries again, and lets the answer decide.
///
/// Wrap it around whatever is only on screen while the data is stale — the
/// **Nincs kapcsolat** / **Szerverhiba** mark itself. Its lifetime is then the
/// right lifetime: the retries start when the mark goes up and stop when it
/// goes away, with no separate state to keep in step.
class StaleDataRetry extends StatefulWidget {
  const StaleDataRetry({super.key, required this.onRetry, required this.child});

  /// Short enough that the user sees the screen heal by itself rather than
  /// giving up on it, long enough not to hammer a server that just answered
  /// with an error. A failed call costs little: with the radio off it gives up
  /// at once, and the screen is only ever showing stale data while this runs.
  static const Duration retryEvery = Duration(seconds: 20);

  /// Fetches again. Its result reaches the screen the usual way, through the
  /// screen's own state — this widget never reads it.
  final Future<void> Function() onRetry;

  final Widget child;

  @override
  State<StaleDataRetry> createState() => _StaleDataRetryState();
}

class _StaleDataRetryState extends State<StaleDataRetry>
    with WidgetsBindingObserver {
  Timer? _timer;

  /// A slow call must not have a second one started on top of it, which on a
  /// timeout is exactly when the timer comes round again.
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(StaleDataRetry.retryEvery, (_) => _retry());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Someone who turned the connection back on in the phone's settings comes
  /// back expecting live data, without waiting out the timer.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _retry();
  }

  Future<void> _retry() async {
    if (_retrying) return;
    _retrying = true;
    try {
      await widget.onRetry();
    } finally {
      // The screen may have dropped this widget on a successful answer, which
      // is the point — there is simply nothing left to schedule.
      if (mounted) _retrying = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
