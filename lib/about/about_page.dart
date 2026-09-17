import 'package:flutter/material.dart';
import 'package:miserend/widgets/feedback_mail.dart';
import 'package:miserend/widgets/launch_external.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Which version the user runs, who made the app and where its data comes
/// from (spec 0009, „Az appról oldal"). The map's attribution is not repeated
/// here: the map already shows it.
class AboutPage extends StatefulWidget {
  const AboutPage({super.key, this.feedback});

  /// Injected by tests; the page builds its own otherwise.
  final FeedbackLauncher? feedback;

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  static const String _appName = 'Miserend';

  static final Uri _miserendUri = Uri.parse('https://miserend.hu');

  late final FeedbackLauncher _feedback = widget.feedback ?? FeedbackLauncher();

  late final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Az appról')),
      body: FutureBuilder<PackageInfo>(
        future: _packageInfo,
        builder: (context, snapshot) {
          final info = snapshot.data;
          final version =
              info == null ? null : '${info.version} (${info.buildNumber})';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(_appName, style: textTheme.headlineSmall),
              if (version != null) Text('Verzió: $version'),
              const SizedBox(height: 24),
              // The whole sentence opens the site: a tap target the size of
              // one word is hard to hit.
              InkWell(
                onTap: () => launchExternal(context, _miserendUri),
                child: Text.rich(
                  TextSpan(
                    text: 'Az adatokat a ',
                    children: [
                      TextSpan(
                        text: 'miserend.hu',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const TextSpan(text: ' szolgáltatja.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Készítette: Szent József Hackathon'),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _feedback.send(context),
                icon: const Icon(Icons.mail_outline),
                label: const Text('Visszajelzés küldése'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed:
                    () => showLicensePage(
                      context: context,
                      applicationName: _appName,
                      applicationVersion: version,
                    ),
                child: const Text('Nyílt forrású licencek'),
              ),
            ],
          );
        },
      ),
    );
  }
}
