import 'package:flutter/material.dart';
import 'package:miserend/church_details/widgets/expandable_info_tile.dart';
import 'package:miserend/church_details/widgets/section_card.dart';
import 'package:miserend/colors.dart';
import 'package:miserend/widgets/launch_external.dart';
import 'package:miserend/widgets/miserend_text.dart';

/// Email, the church's own links, and the parish block.
///
/// The parish text is shown as written. It runs the priest's name, the office
/// address, a phone number, opening hours and the office manager together in
/// one entity-encoded paragraph, with no separate phone field to link from —
/// picking the number back out of it with a pattern is explicitly out of scope.
class ContactCard extends StatelessWidget {
  const ContactCard({
    super.key,
    required this.email,
    required this.links,
    required this.parish,
  });

  final String? email;
  final List<String> links;
  final String? parish;

  /// Whether there is anything at all to put in the card. The API returns an
  /// empty string for a missing email rather than null.
  static bool hasContent({
    required String? email,
    required List<String> links,
    required String? parish,
  }) {
    return (email != null && email.trim().isNotEmpty) ||
        links.any((link) => link.trim().isNotEmpty) ||
        !MiserendText.isEmpty(parish);
  }

  @override
  Widget build(BuildContext context) {
    final email = this.email?.trim() ?? '';
    final parishText = MiserendText.normalize(parish);
    final links =
        this.links
            .map((link) => link.trim())
            .where((l) => l.isNotEmpty)
            .toList();

    return SectionCard(
      title: 'Elérhetőség',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (email.isNotEmpty)
            _row(
              context,
              icon: Icons.mail_outline,
              label: email,
              onTap:
                  () => launchExternal(
                    context,
                    Uri(scheme: 'mailto', path: email),
                  ),
            ),
          for (final link in links)
            _row(
              context,
              icon: Icons.link,
              label: _label(link),
              onTap: () {
                final uri = Uri.tryParse(link);
                if (uri != null) {
                  launchExternal(context, uri);
                }
              },
            ),
          if (parishText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ExpandableInfoTile(text: parishText),
            ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.black54),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.apply(color: CustomColors.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The host rather than the whole URL: "belvarosiplebania.hu" says more at a
  /// glance than "http://belvarosiplebania.hu/", and wraps less badly.
  String _label(String link) {
    final host = Uri.tryParse(link)?.host ?? '';
    if (host.isEmpty) {
      return link;
    }
    return host.startsWith('www.') ? host.substring(4) : host;
  }
}
