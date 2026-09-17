import 'package:flutter/material.dart';
import 'package:miserend/database/cache/church_details.dart';
import 'package:miserend/database/cache/church_list_entry.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/home/churches/church_card.dart';
import 'package:miserend/menu/church_of_the_day_loader.dart';
import 'package:miserend/widgets/feedback_mail.dart';
import 'package:miserend/widgets/launch_external.dart';
import 'package:miserend/widgets/miserend_text.dart';
import 'package:miserend/widgets/photo_decode.dart';
import 'package:miserend/widgets/section_card.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

/// Opened from the bottom navigation's Menü item: the web version, a church
/// to discover, the app's version and the way to send feedback (spec 0009,
/// „Menü oldal").
class MenuPage extends StatefulWidget {
  const MenuPage({
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
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  /// The web version, with the same data as the app.
  static final Uri _webVersion = Uri.parse('https://miserend.hu');

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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Menü')),
      // The grey the Templomok and Misék tabs draw their lists on, so the
      // menu looks like the same app.
      body: Container(
        color: Colors.black12,
        child: ListView(
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
            if (_church case final church?) _churchOfTheDay(church),
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
                      info == null
                          ? ''
                          : '${info.version} (${info.buildNumber})',
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

  /// The details page's card margins, so the menu reads as the same app.
  Widget _card(Widget child) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: child,
    );
  }
}
