import 'package:flutter/material.dart';
import 'package:miserend/bootstrap/bootstrap_progress_page.dart';
import 'package:miserend/bootstrap/cache_bootstrap.dart';
import 'package:miserend/bootstrap/export_size.dart';
import 'package:miserend/home/home.dart';
import 'package:miserend/theme/adaptive.dart';

/// Opens the home screen, after offering the bootstrap import with its size
/// once (ADR-0006, spec 0015, „Splash"): until it has succeeded or the user
/// turned it down, and only when the size comes back, since without an
/// answer the download could not be accepted anyway.
class RouteSplash extends StatefulWidget {
  const RouteSplash({super.key, this.bootstrap, this.homeBuilder = _home});

  /// Injected by tests; the app's own otherwise.
  final CacheBootstrap? bootstrap;

  /// Injected by tests; the real home screen otherwise.
  final WidgetBuilder homeBuilder;

  static Widget _home(BuildContext context) => const HomeScreen();

  @override
  State<RouteSplash> createState() => _RouteSplashState();
}

class _RouteSplashState extends State<RouteSplash> {
  late final CacheBootstrap _bootstrap =
      widget.bootstrap ?? CacheBootstrap.shared;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await _bootstrap.restore();
    if (_bootstrap.done.value || _bootstrap.declined) {
      _goToHome();
      return;
    }

    final size = await _bootstrap.exportSize();
    if (size == null) {
      _goToHome();
      return;
    }
    if (!mounted) return;

    final download = await showMiserendDialog<bool>(
      context,
      title: 'Templomok és misék letöltése',
      content:
          'A jobb élményhez töltsd le egyszer a templomok és misék adatait '
          '(${ExportSize.label(size)}). Nélküle az app csak korlátozottan '
          'működik. A letöltést később a Névjegyen is elindíthatod.',
      actions: const [
        MiserendDialogAction('Most nem', false),
        MiserendDialogAction('Letöltés', true),
      ],
      // A choice to make, not to tap away.
      barrierDismissible: false,
    );
    if (!mounted) return;
    switch (download) {
      case true:
        await BootstrapProgressPage.open(context, _bootstrap);
      case false:
        await _bootstrap.decline();
      case null:
        // Gone without an answer, as by Android's back: no choice was made,
        // and it is offered again on the next start.
        break;
    }
    _goToHome();
  }

  void _goToHome() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: widget.homeBuilder),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator.adaptive()),
    );
  }
}
