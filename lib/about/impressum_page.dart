import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:miserend/widgets/launch_external.dart';
import 'package:miserend/widgets/section_card.dart';

/// Who publishes and who builds the app, how to support it, where its source
/// is, and the licences it is built on (spec 0014, „Impresszum").
///
/// The publisher (the Rendtartomány) and the foundation the 1% goes to (the
/// Alapítvány) are two organisations with two tax numbers; the one shown is
/// the Alapítvány's, and only beside the sentence that names it
/// (docs/MENU-ES-IMPRESSZUM.md, §2.5).
class ImpressumPage extends StatelessWidget {
  const ImpressumPage({super.key, this.openLink});

  /// Injected by tests; the page hands links to the device otherwise.
  final Future<bool> Function(Uri uri)? openLink;

  static final Uri _publisherSite = Uri.parse('https://jezsuita.hu');

  static final Uri _sourceCode = Uri.parse(
    'https://github.com/szanatil/Miserend-Flutter',
  );

  /// The Jézus Társasága Alapítvány's, for the 1% offer.
  static const String _foundationTaxNumber = '18064333-2-42';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Impresszum')),
      // The Névjegy page's grey, so the two read as one place.
      body: Container(
        color: Colors.black12,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            SectionCard(
              title: 'Kiadó',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Text(
                    'Jézus Társasága Magyarországi Rendtartománya',
                    style: textTheme.titleMedium,
                  ),
                  const Text('1085 Budapest, Horánszky u. 20.'),
                  _link(context, 'jezsuita.hu', _publisherSite),
                ],
              ),
            ),
            const SectionCard(
              title: 'Fejlesztő',
              child: Text('Az alkalmazást a Szent József Hackathon fejleszti.'),
            ),
            SectionCard(
              title: 'Támogatás',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  const Text(
                    'Ha támogatni szeretnéd munkánkat, ajánld fel adód '
                    '1%-át a Jézus Társasága Alapítványnak.',
                  ),
                  Row(
                    children: [
                      const Text('Adószám: '),
                      Text(
                        _foundationTaxNumber,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Adószám másolása',
                        icon: const Icon(Icons.copy, color: Colors.black54),
                        onPressed: () => _copyTaxNumber(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SectionCard(
              title: 'Forráskód',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  const Text(
                    'Ha fejlesztenél valamit az alkalmazáson, itt találod a '
                    'forráskódját:',
                  ),
                  _link(context, 'A projekt a GitHubon', _sourceCode),
                ],
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: const Icon(
                  Icons.description_outlined,
                  color: Colors.black54,
                ),
                title: const Text('Felhasznált licencek'),
                subtitle: const Text(
                  'A programcsomagok, amelyekre az app épül',
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Colors.black54,
                ),
                onTap:
                    () => showLicensePage(
                      context: context,
                      applicationName: 'Miserend',
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _link(BuildContext context, String label, Uri uri) {
    return InkWell(
      onTap: () => launchExternal(context, uri, launch: openLink),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            Text(
              label,
              style: TextStyle(color: Theme.of(context).primaryColor),
            ),
            Icon(
              Icons.open_in_new,
              size: 16,
              color: Theme.of(context).primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyTaxNumber(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(const ClipboardData(text: _foundationTaxNumber));
    messenger.showSnackBar(
      const SnackBar(content: Text('Adószám vágólapra másolva')),
    );
  }
}
