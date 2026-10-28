import 'package:flutter/material.dart';
import 'package:miserend/about/church_of_the_day_loader.dart';
import 'package:miserend/bootstrap/bootstrap_progress_page.dart';
import 'package:miserend/bootstrap/cache_bootstrap.dart';
import 'package:miserend/bootstrap/export_size.dart';
import 'package:miserend/database/cache/church_details.dart';
import 'package:miserend/database/cache/church_list_entry.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/home/churches/church_card.dart';
import 'package:miserend/theme/tokens.dart';
import 'package:miserend/widgets/content_width.dart';
import 'package:miserend/widgets/feedback_mail.dart';
import 'package:miserend/widgets/launch_external.dart';
import 'package:miserend/widgets/miserend_text.dart';
import 'package:miserend/widgets/photo_decode.dart';
import 'package:miserend/widgets/photo_fade_in.dart';
import 'package:miserend/widgets/section_card.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

/// Opened from the bottom navigation's Névjegy item: the bootstrap import
/// until it has succeeded (spec 0015), a church to discover, the app's
/// developer and version, its source code and the web version, under a
/// floating button to send feedback (spec 0014).
class AboutPage extends StatefulWidget {
  const AboutPage({
    super.key,
    this.feedback,
    this.openLink,
    this.churchOfTheDay,
    this.bootstrap,
    this.isActive = true,
    this.clock = DateTime.now,
  });

  /// Injected by tests; the page builds its own otherwise.
  final FeedbackLauncher? feedback;

  /// Injected by tests; the page hands links to the device otherwise.
  final Future<bool> Function(Uri uri)? openLink;

  /// Injected by tests; the page builds its own otherwise.
  final ChurchOfTheDayLoader? churchOfTheDay;

  /// Injected by tests; the app's own otherwise.
  final CacheBootstrap? bootstrap;

  /// Whether the tab is the one on screen. The home screen keeps it alive
  /// underneath the others, and each opening asks the export's size again.
  final bool isActive;

  /// Which day's church is shown.
  final DateTime Function() clock;

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  /// The web version, with the same data as the app.
  static final Uri _webVersion = Uri.parse('https://miserend.hu');

  static final Uri _sourceCode = Uri.parse(
    'https://github.com/szanatil/Miserend-Flutter',
  );

  /// Room below the last tile so it can scroll clear of the floating
  /// feedback button: the button's 56 plus its margin, and a gap.
  static const double _feedbackClearance = 56 + Spacing.l + Spacing.l;

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

  late final CacheBootstrap _bootstrap =
      widget.bootstrap ?? CacheBootstrap.shared;

  /// The export's size as of opening the page; null while it is asked for,
  /// and when it did not come back.
  int? _exportSize;

  @override
  void initState() {
    super.initState();
    _loadChurch();
    if (!_bootstrap.done.value) _loadExportSize();
  }

  @override
  void didUpdateWidget(AboutPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive && !_bootstrap.done.value) {
      _loadExportSize();
    }
  }

  /// Asked live: the export is made anew every day, and its size changes
  /// (spec 0015, „Further Notes").
  Future<void> _loadExportSize() async {
    final size = await _bootstrap.exportSize();
    if (!mounted) return;
    setState(() => _exportSize = size);
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
      appBar: AppBar(title: const Text('Névjegy')),
      // Floats so it is in view without scrolling on any phone; in the list
      // it would sit below the fold under the church of the day.
      floatingActionButton: FloatingActionButton.extended(
        // No hero: the Térkép tab's button lives beside this one, and two
        // default tags fail a full-screen push over the tabs.
        heroTag: null,
        onPressed: () => _feedback.send(context),
        icon: const Icon(Icons.mail_outline_rounded),
        label: const Text('Visszajelzés'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: ContentWidth(
        padding: const EdgeInsets.only(
          top: Spacing.s,
          bottom: _feedbackClearance,
        ),
        builder:
            (context, padding) => ListView(
              padding: padding,
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: _bootstrap.done,
                  builder:
                      (context, done, _) =>
                          done ? const SizedBox.shrink() : _bootstrapTile(),
                ),
                if (_church case final church?) _churchOfTheDay(church),
                SectionCard(
                  title: 'Fejlesztő',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: Spacing.s,
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
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
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
                    spacing: Spacing.s,
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
                  margin: SectionCard.margin,
                  child: ListTile(
                    leading: const Icon(Icons.language_rounded),
                    title: const Text('miserend.hu'),
                    subtitle: const Text('A miserend webes változata'),
                    trailing: const Icon(Icons.open_in_new_rounded),
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

  /// The one place the bootstrap import can be started once the user has
  /// turned it down (ADR-0006). A size that did not come back does not stop
  /// it: the progress screen says if the download fails.
  Widget _bootstrapTile() {
    return SectionCard(
      title: 'Templomok és misék letöltése',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: Spacing.s,
        children: [
          const Text(
            'Letöltés nélkül csak a közeli és a már megnézett templomok '
            'érhetők el a keresésben, a Részletes keresőben és a Térképen. Ha '
            'meggondoltad magad, itt egyszer letöltheted az összes templom és '
            'mise adatait.',
          ),
          Center(
            child: FilledButton.icon(
              onPressed: () => BootstrapProgressPage.open(context, _bootstrap),
              icon: const Icon(Icons.download_rounded),
              label: Text('Letöltés (${ExportSize.label(_exportSize)})'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _externalLink(String label, Uri uri) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return InkWell(
      onTap: () => launchExternal(context, uri, launch: widget.openLink),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: Spacing.s,
          children: [
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(color: color),
              ),
            ),
            Icon(Icons.open_in_new_rounded, color: color),
          ],
        ),
      ),
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
          spacing: Spacing.s,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.s),
              child: SizedBox(
                height: _photoHeight,
                width: double.infinity,
                child: _photo(church),
              ),
            ),
            Text(church.name ?? '', style: textTheme.titleMedium),
            if (address.isNotEmpty)
              Text(
                address,
                style: textTheme.bodyMedium?.apply(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            if (description.isNotEmpty)
              // Whole, wrapping: nothing is cut off (DESIGN.md EL2).
              Text(description),
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
    return PhotoFadeIn(
      image: church.photos.first,
      placeholder: _placeholder,
      imageErrorBuilder: (context, error, stackTrace) => placeholder,
      imageCacheHeight: decodeHeight,
      placeholderCacheHeight: decodeHeight,
    );
  }

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
