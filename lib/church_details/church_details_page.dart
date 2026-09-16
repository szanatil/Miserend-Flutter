import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:miserend/church_details/church_page_data.dart';
import 'package:miserend/church_details/church_schedule_loader.dart';
import 'package:miserend/church_details/report_problem_popup.dart';
import 'package:miserend/church_details/widgets/adoration_card.dart';
import 'package:miserend/church_details/widgets/church_info_tiles.dart';
import 'package:miserend/church_details/widgets/confession_tile.dart';
import 'package:miserend/church_details/widgets/contact_card.dart';
import 'package:miserend/church_details/widgets/day_label.dart';
import 'package:miserend/church_details/widgets/expandable_info_tile.dart';
import 'package:miserend/church_details/widgets/mass_info.dart';
import 'package:miserend/church_details/widgets/photo_header.dart';
import 'package:miserend/church_details/widgets/section_card.dart';
import 'package:miserend/colors.dart';
import 'package:miserend/database/cache/cached_mass.dart';
import 'package:miserend/database/cache/church_details.dart';
import 'package:miserend/database/church.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/widgets/miserend_map.dart';
import 'package:miserend/widgets/miserend_text.dart';
import 'package:miserend/widgets/offline_notice.dart';
import 'package:miserend/widgets/time_chip.dart';
import 'package:provider/provider.dart';

class ChurchDetailsPage extends StatefulWidget {
  const ChurchDetailsPage({super.key, required this.church, this.loader});

  /// The row the calling list already had. It seeds the name and the map while
  /// the cache read is in flight; everything the page renders afterwards comes
  /// from [ChurchDetails].
  final Church church;

  /// Injected by tests; the page builds its own otherwise.
  final ChurchScheduleLoader? loader;

  @override
  State<ChurchDetailsPage> createState() => _ChurchDetailsPageState();
}

class _ChurchDetailsPageState extends State<ChurchDetailsPage> {
  /// Collapsed-to-expanded height of the photo header.
  static const double _headerHeight = 200;

  ChurchPageData? _data;
  late final DateTime _today = _midnightToday();

  var isFavorite = false;

  @override
  void initState() {
    super.initState();
    loadMasses();
    isFavorite = Provider.of<FavoritesService>(
      context,
      listen: false,
    ).isFavorite(widget.church.id);
  }

  ChurchDetails? get _details => _data?.church;

  List<List<CachedMass>> get _masses => _data?.massesByDay ?? const [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              expandedHeight: _headerHeight,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                background: ChurchPhotoHeader(
                  photos: _photos(),
                  height: _headerHeight,
                  heroPrefix: 'church-${widget.church.id}-photo',
                ),
              ),
            ),
          ];
        },
        body: Column(
          children: [
            // Like the lists' banner: fixed under the header, shown only once
            // a refresh has failed.
            if (_data?.failure case final failure?)
              OfflineBanner(
                failure: failure,
                asOf: _data?.dataAsOf,
                onRetry: _refresh,
              ),
            Expanded(child: _sections()),
          ],
        ),
      ),
    );
  }

  /// Every section of the page, in reading order.
  Widget _sections() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _churchName(),
        _actionButtons(),
        _massCard(),
        _dayStrip(),
        ..._adorationSection(),
        if (_data?.confessionLive ?? false) const ConfessionTile(),
        _mapCard(),
        ..._contactSection(),
        ..._infoTiles(),
        _updatedFooter(),
      ],
    );
  }

  /// The cached photo list, falling back to the single image the calling list
  /// already had so the header is not blank on the very first frame.
  List<String> _photos() {
    final photos = _details?.photos ?? const <String>[];
    if (photos.isNotEmpty) {
      return photos;
    }
    final legacy = widget.church.imageUrl;
    return (legacy != null && legacy.isNotEmpty) ? [legacy] : const [];
  }

  Widget _churchName() {
    final name = _details?.name ?? widget.church.name ?? '';
    final commonName = _details?.commonName ?? widget.church.commonName ?? '';
    final address = _address();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(name, style: Theme.of(context).textTheme.titleLarge),
          if (commonName.isNotEmpty)
            Text(
              commonName,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.apply(color: Colors.black45),
            ),
          if (address.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: InkWell(
                onTap: _showLocationOnMap,
                child: Row(
                  children: [
                    const Icon(
                      Icons.place_outlined,
                      size: 18,
                      color: Colors.black54,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        address,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.apply(color: Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _address() {
    final city = _details?.city ?? widget.church.city ?? '';
    final street = _details?.street ?? widget.church.street ?? '';
    return [
      city,
      street,
    ].map((part) => part.trim()).where((part) => part.isNotEmpty).join(', ');
  }

  Widget _actionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 24,
        children: [
          GestureDetector(
            onTap: _toggleFavorites,
            child: Column(
              spacing: 8,
              children: [
                Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  size: 32,
                  color: Colors.black54,
                ),
                Text('Kedvencekhez'),
              ],
            ),
          ),
          GestureDetector(
            onTap: _showReportPopup,
            child: Column(
              spacing: 8,
              children: [
                Icon(Icons.error, size: 32, color: Colors.black54),
                Text('Hibajelentés'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _massCard() {
    if (_data?.churchGone ?? false) {
      return SectionCard(
        child: Text(
          'Ez a templom már nem szerepel a miserend.hu-n.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }

    final note = MiserendText.normalize(_details?.massScheduleNote);
    final sundayOffset = DateTime.sunday - DateTime.now().weekday;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Ma', style: Theme.of(context).textTheme.titleLarge),
          _massListWidgetForDay(0),
          // On a Sunday the two headings would name the same day, and the
          // section would repeat itself.
          if (sundayOffset != 0) ...[
            const SizedBox(height: 8),
            Text(
              'Most vasárnap',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            _massListWidgetForDay(sundayOffset),
          ],
          if (note.isNotEmpty) ...[
            const SizedBox(height: 12),
            ExpandableInfoTile(
              title: 'Megjegyzés a miserendhez',
              text: note,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.apply(color: Colors.black54),
            ),
          ],
        ],
      ),
    );
  }

  /// The chips for one day, or a sentence saying which kind of nothing this is.
  ///
  /// An empty day means "no mass" only once a response has actually arrived;
  /// before that it means "not downloaded yet", and on a mass-times app the two
  /// must not look alike.
  Widget _massListWidgetForDay(int offset) {
    final masses =
        offset >= 0 && offset < _masses.length
            ? _masses[offset]
            : const <CachedMass>[];

    if (masses.isEmpty) {
      final fresh = _data?.scheduleIsFresh ?? false;
      final String text;
      if (fresh) {
        text = 'Ezen a napon nincs mise';
      } else {
        text =
            offset == 0
                ? 'Nincs adat a mai miserendről'
                : 'Nincs adat erről a napról';
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.apply(color: Colors.black45),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [for (final mass in masses) _timeChip(mass)],
      ),
    );
  }

  TimeChip _timeChip(CachedMass mass) {
    final meaningful = MassInfo.isMeaningful(mass.info);
    return TimeChip(
      time: TimeOfDay.fromDateTime(mass.time),
      hasInfo: meaningful,
      onTap: meaningful ? () => MassInfo.show(context, mass) : null,
    );
  }

  /// One card per day that actually has masses. Days we know nothing about get
  /// no card at all, so the strip never shows an empty box that reads as "no
  /// mass held" — the bootstrap import only fills seven days, while the strip
  /// used to draw nineteen.
  Widget _dayStrip() {
    final days = <int>[
      for (var offset = 1; offset < _masses.length; offset++)
        if (_masses[offset].isNotEmpty) offset,
    ];
    if (days.isEmpty) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [for (final offset in days) _getMassListCardForDay(offset)],
      ),
    );
  }

  Widget _getMassListCardForDay(int dayOffset) {
    final dateTime = _today.add(Duration(days: dayOffset));
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: SizedBox(
        width: 160,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DayLabel.forDate(dateTime, _today),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(DayLabel.date.format(dateTime)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final mass in _masses[dayOffset]) _timeChip(mass),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _adorationSection() {
    final adorations = _details?.adorations ?? const [];
    if (adorations.isEmpty) {
      return const [];
    }
    return [AdorationCard(adorations: adorations, today: _today)];
  }

  List<Widget> _contactSection() {
    final details = _details;
    if (details == null) {
      return const [];
    }
    if (!ContactCard.hasContent(
      email: details.email,
      links: details.links,
      parish: details.parish,
    )) {
      return const [];
    }
    return [
      ContactCard(
        email: details.email,
        links: details.links,
        parish: details.parish,
      ),
    ];
  }

  List<Widget> _infoTiles() {
    final details = _details;
    if (details == null) {
      return const [];
    }
    final description = MiserendText.normalize(details.description);
    return [
      if (description.isNotEmpty)
        SectionCard(
          title: 'Leírás',
          child: ExpandableInfoTile(text: description),
        ),
      if (AccessibilityTile.hasContent(details.accessibility))
        AccessibilityTile(accessibility: details.accessibility!),
      if (LanguagesTile.hasContent(details.languages))
        LanguagesTile(languages: details.languages),
      if (CommunitiesTile.hasContent(details.communities))
        CommunitiesTile(communities: details.communities),
    ];
  }

  /// When miserend.hu last edited the record — not when this phone last spoke
  /// to the API, which is `local_synced_at` and only surfaces in the (i)
  /// explanation once a refresh has failed.
  Widget _updatedFooter() {
    final updatedAt = _details?.updatedAt;
    if (updatedAt == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Text(
        'Frissítve: ${DayLabel.date.format(updatedAt)}',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.apply(color: Colors.black38),
      ),
    );
  }

  Widget _mapCard() {
    final gettingThere = MiserendText.normalize(
      _details?.gettingThere ?? widget.church.gettingThere,
    );

    return SectionCard(
      title: 'Megközelítés',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: _showLocationOnMap,
            child: SizedBox(
              height: 200,
              child: MiserendMap(
                interactive: false,
                initialCenter: _location(),
                initialZoom: 17,
                compactAttribution: true,
                apiKey: const String.fromEnvironment('CARTO_API_KEY'),
                markers: [
                  MiserendMapMarker(id: widget.church.id, point: _location()),
                ],
              ),
            ),
          ),
          if (gettingThere.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ExpandableInfoTile(text: gettingThere),
            ),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Divider(height: 1),
          ),
          GestureDetector(
            onTap: _showDirectionsOnMap,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'ÚTVONAL',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium!.apply(color: CustomColors.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  LatLng _location() {
    final lat = _details?.lat ?? widget.church.lat;
    final lon = _details?.lon ?? widget.church.lon;
    return (lat != null && lon != null)
        ? LatLng(lat, lon)
        : widget.church.location;
  }

  Future<void> _toggleFavorites() async {
    unawaited(
      Provider.of<FavoritesService>(
        context,
        listen: false,
      ).toggle(widget.church.id),
    );
    setState(() {
      isFavorite = !isFavorite;
    });
  }

  ChurchScheduleLoader get _loader =>
      widget.loader ??
      ChurchScheduleLoader(
        onChurchesGone:
            Provider.of<FavoritesService>(context, listen: false).removeAll,
      );

  /// Renders whatever the cache holds, then again once the API has answered.
  Future<void> loadMasses() async {
    final cached = await _loader.loadCached(widget.church.id, _today);
    if (!mounted) {
      return;
    }
    setState(() => _data = cached);
    await _refresh();
  }

  /// Asks the API again, without dropping back to the cache first: what is on
  /// screen came from there already, and reading it again would blink the
  /// **Nincs kapcsolat** strip off and on at every retry.
  Future<void> _refresh() async {
    final fresh = await _loader.refresh(widget.church, _today);
    if (!mounted) {
      return;
    }
    setState(() {
      _data = fresh;
      if (fresh.churchGone) isFavorite = false;
    });
  }

  DateTime _midnightToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void _showReportPopup() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: StatefulBuilder(
            // You need this, notice the parameters below:
            builder: (BuildContext context, StateSetter setState) {
              return ReportPopup(church: widget.church);
            },
          ),
        );
      },
    );
  }

  void _showLocationOnMap() async {
    final map = await _firstInstalledMap();
    if (map == null) {
      return;
    }
    final location = _location();
    await map.showMarker(
      coords: Coords(location.latitude, location.longitude),
      title: _details?.name ?? widget.church.name ?? '',
      description: _details?.commonName ?? widget.church.commonName ?? '',
    );
  }

  void _showDirectionsOnMap() async {
    final map = await _firstInstalledMap();
    if (map == null) {
      return;
    }
    final location = _location();
    await map.showDirections(
      destination: Coords(location.latitude, location.longitude),
      destinationTitle: _details?.name ?? widget.church.name ?? '',
    );
  }

  /// Null when the device has no map application at all, which is the case on
  /// a phone shipped without Google Maps. Taking the first entry of an empty
  /// list crashed the page instead.
  Future<AvailableMap?> _firstInstalledMap() async {
    final availableMaps = await MapLauncher.installedMaps;
    if (availableMaps.isNotEmpty) {
      return availableMaps.first;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nincs telepítve térkép alkalmazás a készüléken.'),
        ),
      );
    }
    return null;
  }
}
