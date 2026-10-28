import 'dart:async';

import 'package:flutter/material.dart';
import 'package:miserend/bootstrap/cache_bootstrap.dart';
import 'package:miserend/bootstrap/export_size.dart';
import 'package:miserend/theme/tokens.dart';
import 'package:miserend/widgets/content_width.dart';
import 'package:miserend/widgets/list_status_view.dart';

/// Runs the bootstrap import over the whole screen, in its two steps — the
/// download in megabytes, then the import — and closes itself when the run
/// ends (spec 0015, „Folyamatjelző képernyő"). The splash and the Névjegy
/// both open it; it hands back to whichever did.
class BootstrapProgressPage extends StatefulWidget {
  const BootstrapProgressPage({super.key, required this.bootstrap});

  final CacheBootstrap bootstrap;

  /// Over the tabs as well: a task to finish or to stop (DESIGN.md NA1, NA2).
  static Future<void> open(BuildContext context, CacheBootstrap bootstrap) =>
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => BootstrapProgressPage(bootstrap: bootstrap),
        ),
      );

  /// How long a failure is said before the page closes: as long as a
  /// snackbar stays (DESIGN.md KO15).
  static const Duration failureShown = Duration(seconds: 4);

  @override
  State<BootstrapProgressPage> createState() => _BootstrapProgressPageState();
}

enum _StepState { pending, current, done }

class _BootstrapProgressPageState extends State<BootstrapProgressPage> {
  late final StreamSubscription<BootstrapProgress> _run;

  /// The download's last report; its numbers stay once the import is on.
  BootstrapDownloading _download = const BootstrapDownloading(0, null);
  bool _importing = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _run = widget.bootstrap.run().listen(_onProgress);
  }

  @override
  void dispose() {
    unawaited(_run.cancel());
    super.dispose();
  }

  void _onProgress(BootstrapProgress progress) {
    if (!mounted) return;
    switch (progress) {
      case BootstrapDownloading():
        setState(() => _download = progress);
      case BootstrapImporting():
        setState(() => _importing = true);
      case BootstrapDone():
      case BootstrapCancelled():
        Navigator.of(context).pop();
      case BootstrapFailed():
        setState(() => _failed = true);
        Future<void>.delayed(BootstrapProgressPage.failureShown, () {
          if (mounted) Navigator.of(context).pop();
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _download.total;
    final downloading = !_importing && !_failed;
    // The bar keeps its own Spacing.l from the edge (DESIGN.md KO8); the rest
    // of the page gets the same.
    const gutter = EdgeInsets.symmetric(horizontal: Spacing.l);
    return PopScope(
      // Leaving would not stop the download; „Mégse" does.
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: Spacing.l),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: ContentWidth.maxWidth,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: gutter,
                      child: Text(
                        'Templomok és misék letöltése',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(height: Spacing.xl),
                    // A bar only while it is known how far the work has got:
                    // the download with its size. The import and a download
                    // of unknown size get the spinner (DESIGN.md KO8).
                    LoadingProgress(
                      value:
                          downloading && total != null && total > 0
                              ? _download.received / total
                              : null,
                      caption:
                          '${ExportSize.megabytes(_download.received)} / '
                          '${ExportSize.label(total)}',
                    ),
                    const SizedBox(height: Spacing.l),
                    Padding(
                      padding: gutter,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Step(
                            label: 'Letöltés',
                            state:
                                _importing
                                    ? _StepState.done
                                    : _StepState.current,
                          ),
                          const SizedBox(height: Spacing.s),
                          _Step(
                            label: 'Import',
                            state:
                                _importing
                                    ? _StepState.current
                                    : _StepState.pending,
                          ),
                          if (_failed) ...[
                            const SizedBox(height: Spacing.l),
                            Text(
                              'A letöltés nem sikerült. Később újra '
                              'megpróbálhatod a Névjegyen.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                          if (downloading) ...[
                            const SizedBox(height: Spacing.xl),
                            Center(
                              child: FilledButton.tonal(
                                onPressed: widget.bootstrap.cancel,
                                child: const Text('Mégse'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One step of the run: its mark and its name.
class _Step extends StatelessWidget {
  const _Step({required this.label, required this.state});

  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = state == _StepState.current;
    final iconColor =
        current
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant;
    return MergeSemantics(
      child: Semantics(
        selected: current,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(switch (state) {
              _StepState.pending => Icons.radio_button_unchecked_rounded,
              _StepState.current => Icons.radio_button_checked_rounded,
              _StepState.done => Icons.check_circle_outline_rounded,
            }, color: iconColor),
            const SizedBox(width: Spacing.s),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: current ? FontWeight.w600 : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
