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
