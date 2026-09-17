import 'package:flutter/material.dart';
import 'package:miserend/about/about_page.dart';
import 'package:miserend/widgets/feedback_mail.dart';

enum _HomeMenuItem { feedback, about }

/// The ⋮ menu of the home screen's AppBar, on every tab (spec 0009,
/// „Visszajelzés: belépési pont"). Feedback is about the app, not a church's
/// data, so it does not point to the problem report (CONTEXT.md,
/// „Visszajelzés").
class HomeMenuButton extends StatelessWidget {
  const HomeMenuButton({super.key, this.feedback});

  /// Injected by tests; the button builds its own otherwise.
  final FeedbackLauncher? feedback;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_HomeMenuItem>(
      tooltip: 'Menü',
      icon: const Icon(Icons.more_vert, color: Colors.black54),
      onSelected: (item) {
        switch (item) {
          case _HomeMenuItem.feedback:
            (feedback ?? FeedbackLauncher()).send(context);
          case _HomeMenuItem.about:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AboutPage()),
            );
        }
      },
      itemBuilder:
          (context) => const [
            PopupMenuItem(
              value: _HomeMenuItem.feedback,
              child: Text('Visszajelzés'),
            ),
            PopupMenuItem(value: _HomeMenuItem.about, child: Text('Az appról')),
          ],
    );
  }
}
