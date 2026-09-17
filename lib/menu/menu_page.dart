import 'package:flutter/material.dart';
import 'package:miserend/widgets/feedback_mail.dart';
import 'package:miserend/widgets/launch_external.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Opened from the bottom navigation's Menü item: the web version, the app's
/// version and the way to send feedback (spec 0009, „Menü oldal").
class MenuPage extends StatefulWidget {
  const MenuPage({super.key, this.feedback, this.openLink});

  /// Injected by tests; the page builds its own otherwise.
  final FeedbackLauncher? feedback;

  /// Injected by tests; the page hands links to the device otherwise.
  final Future<bool> Function(Uri uri)? openLink;

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  /// The web version, with the same data as the app.
  static final Uri _webVersion = Uri.parse('https://miserend.hu');

  late final FeedbackLauncher _feedback = widget.feedback ?? FeedbackLauncher();

  late final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Menü')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _card(
            ListTile(
              leading: const Icon(Icons.language, color: Colors.black54),
              title: const Text('miserend.hu'),
              subtitle: const Text('A miserend webes változata'),
              trailing: const Icon(Icons.open_in_new, color: Colors.black54),
              onTap:
                  () => launchExternal(
                    context,
                    _webVersion,
                    launch: widget.openLink,
                  ),
            ),
          ),
          _card(
            FutureBuilder<PackageInfo>(
              future: _packageInfo,
              builder: (context, snapshot) {
                final info = snapshot.data;
                return ListTile(
                  leading: const Icon(
                    Icons.info_outline,
                    color: Colors.black54,
                  ),
                  title: const Text('Verzió'),
                  subtitle: Text(
                    info == null ? '' : '${info.version} (${info.buildNumber})',
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: () => _feedback.send(context),
              icon: const Icon(Icons.mail_outline),
              label: const Text('Visszajelzés'),
            ),
          ),
        ],
      ),
    );
  }

  /// The details page's card margins, so the menu reads as the same app.
  Widget _card(Widget child) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: child,
    );
  }
}
