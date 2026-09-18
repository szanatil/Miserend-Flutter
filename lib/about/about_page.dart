import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:miserend/about/church_of_the_day_loader.dart';
import 'package:miserend/database/cache/church_details.dart';
import 'package:miserend/database/cache/church_list_entry.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/home/churches/church_card.dart';
import 'package:miserend/widgets/feedback_mail.dart';
import 'package:miserend/widgets/launch_external.dart';
import 'package:miserend/widgets/miserend_text.dart';
import 'package:miserend/widgets/photo_decode.dart';
import 'package:miserend/widgets/section_card.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

/// Opened from the bottom navigation's Névjegy item: a church to discover,
/// the app's impressum — publisher and how to support it, developer and
/// version, source code — and the web version, under a floating button to
/// send feedback (spec 0014).
class AboutPage extends StatefulWidget {
  const AboutPage({
    super.key,
    this.feedback,
    this.openLink,
    this.churchOfTheDay,
    this.clock = DateTime.now,
  });

  /// Injected by tests; the page builds its own otherwise.
  final FeedbackLauncher? feedback;

  /// Injected by tests; the page hands links to the device otherwise.
  final Future<bool> Function(Uri uri)? openLink;

  /// Injected by tests; the page builds its own otherwise.
  final ChurchOfTheDayLoader? churchOfTheDay;

  /// Which day's church is shown.
  final DateTime Function() clock;

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  /// The web version, with the same data as the app.
  static final Uri _webVersion = Uri.parse('https://miserend.hu');

  static final Uri _publisherSite = Uri.parse('https://jezsuita.hu');

  static final Uri _sourceCode = Uri.parse(
    'https://github.com/szanatil/Miserend-Flutter',
  );

  /// The Jézus Társasága Alapítvány's, for the 1% offer. The publisher (the
  /// Rendtartomány) has a tax number of its own; only the Alapítvány's is
  /// shown, beside the sentence that names it (docs/MENU-ES-IMPRESSZUM.md,
  /// §2.5).
  static const String _foundationTaxNumber = '18064333-2-42';

  /// Room below the last tile so it can scroll clear of the floating
  /// feedback button: the button's 56 plus its 16 margin, and a gap.
  static const double _feedbackClearance = 88;

  late final FeedbackLauncher _feedback = widget.feedback ?? FeedbackLauncher();

  late final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  late final ChurchOfTheDayLoader _churchLoader =
      widget.churchOfTheDay ??
      ChurchOfTheDayLoader(
        onChurchesGone:
            Provider.of<FavoritesService>(context, listen: false).removeAll,
      );

  /// Null until the cache has answered, and when it holds no church.
  ChurchDetails? _church;

  @override
  void initState() {
    super.initState();
    _loadChurch();
  }

  /// The cached church at once, then again once the API has answered: the
  /// description may come with it, or pick another candidate (ADR-0003).
  Future<void> _loadChurch() async {
    final today = widget.clock();
    final cached = await _churchLoader.loadCached(today);
    if (!mounted) return;
    setState(() => _church = cached);
    final fresh = await _churchLoader.refresh(today);
    if (!mounted) return;
    setState(() => _church = fresh);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Névjegy')),
      // Floats so it is in view without scrolling on any phone; in the list
      // it would sit below the fold under the church of the day.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _feedback.send(context),
        icon: const Icon(Icons.mail_outline),
        label: const Text('Visszajelzés'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      // The grey the Templomok and Misék tabs draw their lists on, so the
      // page looks like the same app.
      body: Container(
        color: Colors.black12,
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: _feedbackClearance),
          children: [
            if (_church case final church?) _churchOfTheDay(church),
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
                  _externalLink('jezsuita.hu', _publisherSite),
                  const SizedBox(height: 8),
                  const Text(
                    'Ha támogatni szeretnéd munkánkat, ajánld fel adód '
                    '1%-át a Jézus Társasága Alapítványnak.',
                  ),
                  // Wraps rather than overflows on a narrow phone or with
                  // large text.
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
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
                        onPressed: _copyTaxNumber,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SectionCard(
              title: 'Fejlesztő',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  const Text(
                    'Az alkalmazást a Szent József Hackathon fejleszti.',
                  ),
                  FutureBuilder<PackageInfo>(
                    future: _packageInfo,
                    builder: (context, snapshot) {
                      final info = snapshot.data;
                      if (info == null) return const SizedBox.shrink();
                      return Text(
                        'Verzió: ${info.version} (${info.buildNumber})',
                        style: textTheme.bodyMedium?.apply(
                          color: Colors.black54,
                        ),
                      );
                    },
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
                  _externalLink('A projekt a GitHubon', _sourceCode),
                ],
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
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
          ],
        ),
      ),
    );
  }

  Widget _externalLink(String label, Uri uri) {
    final color = Theme.of(context).primaryColor;
    return InkWell(
      onTap: () => launchExternal(context, uri, launch: widget.openLink),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            Flexible(child: Text(label, style: TextStyle(color: color))),
            Icon(Icons.open_in_new, size: 16, color: color),
          ],
        ),
      ),
    );
  }

  Future<void> _copyTaxNumber() async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(const ClipboardData(text: _foundationTaxNumber));
    messenger.showSnackBar(
      const SnackBar(content: Text('Adószám vágólapra másolva')),
    );
  }

  Widget _churchOfTheDay(ChurchDetails church) {
    final textTheme = Theme.of(context).textTheme;
    final address = [church.city, church.street]
        .map((part) => (part ?? '').trim())
        .where((part) => part.isNotEmpty)
        .join(', ');
    final description = MiserendText.normalize(church.description);
    return SectionCard(
      title: 'Mai templom ajánlatunk',
      child: InkWell(
        onTap: () => openChurchDetails(context, _listEntry(church)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: _photoHeight,
                width: double.infinity,
                child: _photo(church),
              ),
            ),
            const SizedBox(height: 4),
            Text(church.name ?? '', style: textTheme.titleMedium),
            if (address.isNotEmpty)
              Text(
                address,
                style: textTheme.bodyMedium?.apply(color: Colors.black54),
              ),
            if (description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  description,
                  maxLines: _descriptionLines,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static const double _photoHeight = 180;

  static const String _placeholder = 'assets/images/church_blurred.png';

  /// The first photo; the loader only picks churches that have one.
  Widget _photo(ChurchDetails church) {
    final decodeHeight = PhotoDecode.forSlot(context, _photoHeight);
    final placeholder = Image.asset(
      _placeholder,
      fit: BoxFit.cover,
      cacheHeight: decodeHeight,
    );
    if (church.photos.isEmpty) return placeholder;
    return FadeInImage.assetNetwork(
      image: church.photos.first,
      placeholder: _placeholder,
      fit: BoxFit.cover,
      imageErrorBuilder: (context, error, stackTrace) => placeholder,
      imageCacheHeight: decodeHeight,
      placeholderCacheHeight: decodeHeight,
    );
  }

  /// A taste of the description; the whole of it is on the details page.
  static const int _descriptionLines = 4;

  static ChurchListEntry _listEntry(ChurchDetails church) => ChurchListEntry(
    id: church.id,
    name: church.name,
    commonName: church.commonName,
    city: church.city,
    lat: church.lat,
    lon: church.lon,
    photo: church.photos.isEmpty ? null : church.photos.first,
    masses: const [],
  );
}
