import 'package:flutter/material.dart';
import 'package:miserend/theme/tokens.dart';
import 'package:miserend/widgets/content_width.dart';

/// Full-page spinner with a caption, shown while a list is still being built.
/// When how far the work has got is known, [progress] shows it in the
/// spinner's place (DESIGN.md KO8).
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message = 'Betöltés...', this.progress});

  final String message;
  final LoadingProgress? progress;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          progress ?? const CircularProgressIndicator.adaptive(),
          Padding(
            padding: const EdgeInsets.only(top: Spacing.l),
            child: Text(message),
          ),
        ],
      ),
    );
  }
}

/// How far a long piece of work has got: a bar filled to [value] (0 to 1),
/// [caption] under it saying it in numbers (DESIGN.md KO8). It does not say
/// how long is left: the API's answers take too unevenly long to tell.
class LoadingProgress extends StatelessWidget {
  const LoadingProgress({
    super.key,
    required this.value,
    required this.caption,
  });

  final double value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.l),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: ContentWidth.maxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: value),
            const SizedBox(height: Spacing.s),
            Text(
              caption,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-page message, shown when a list has nothing to display.
class MessageView extends StatelessWidget {
  const MessageView({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.l),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

/// A page with nothing to show that says why: an icon, a title and an
/// explanation (DESIGN.md KO8).
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    required this.explanation,
  });

  /// „Nincs találat" where the bootstrap import has not run, which may be
  /// why. It names the one place the download can be started, and offers no
  /// button: the user chose not to download (ADR-0006, spec 0015).
  const EmptyView.withoutBootstrap({super.key})
    : icon = Icons.search_off_rounded,
      title = 'Nincs találat',
      explanation =
          'Lehet, hogy azért, mert nem töltötted le az összes templom '
              'adatait. A letöltést a Névjegyen indíthatod el.';

  final IconData icon;
  final String title;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(Spacing.l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconTheme.merge(
            data: const IconThemeData(size: IconSizes.statusView),
            child: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: Spacing.l),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: Spacing.l),
          Text(
            explanation,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// Stretches [child] over the whole page while keeping it scrollable, so a
/// [RefreshIndicator] around it still lets the user pull down to try again.
class PullableFill extends StatelessWidget {
  const PullableFill({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder:
          (context, constraints) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [SizedBox(height: constraints.maxHeight, child: child)],
          ),
    );
  }
}
