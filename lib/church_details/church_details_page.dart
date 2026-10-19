import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:miserend/calendar_days.dart';
import 'package:miserend/church_details/church_page_data.dart';
import 'package:miserend/church_details/church_schedule_loader.dart';
import 'package:miserend/church_details/report_problem_page.dart';
import 'package:miserend/church_details/widgets/adoration_card.dart';
import 'package:miserend/church_details/widgets/church_info_tiles.dart';
import 'package:miserend/church_details/widgets/confession_tile.dart';
import 'package:miserend/church_details/widgets/contact_card.dart';
import 'package:miserend/church_details/widgets/day_label.dart';
import 'package:miserend/church_details/widgets/expandable_info_tile.dart';
import 'package:miserend/church_details/widgets/mass_info.dart';
import 'package:miserend/church_details/widgets/photo_header.dart';
import 'package:miserend/database/cache/cached_mass.dart';
import 'package:miserend/database/cache/church_details.dart';
import 'package:miserend/database/church.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/home/masses/nearest_masses.dart';
import 'package:miserend/theme/adaptive.dart';
import 'package:miserend/theme/miserend_colors.dart';
import 'package:miserend/theme/miserend_theme.dart';
import 'package:miserend/theme/tokens.dart';
import 'package:miserend/widgets/card_columns.dart';
import 'package:miserend/widgets/content_width.dart';
import 'package:miserend/widgets/miserend_map.dart';
import 'package:miserend/widgets/miserend_text.dart';
import 'package:miserend/widgets/offline_notice.dart';
import 'package:miserend/widgets/section_card.dart';
import 'package:miserend/widgets/time_chip.dart';
import 'package:provider/provider.dart';

class ChurchDetailsPage extends StatefulWidget {
  const ChurchDetailsPage({
    super.key,
    required this.church,
    this.loader,
    this.clock = DateTime.now,
  });

  /// The row the calling list already had. It seeds the name and the map while
  /// the cache read is in flight; everything the page renders afterwards comes
  /// from [ChurchDetails].
  final Church church;

  /// Injected by tests; the page builds its own otherwise.
  final ChurchScheduleLoader? loader;

  /// The time now, for today and the masses going on. Injected by tests.
  final DateTime Function() clock;

  /// A day card's least width in the strip at text scale 1.0; a day with
  /// more masses grows wider instead of taller, an empty day's text wraps
  /// within it.
  static const double dayCardMinWidth = 160;

  @override
  State<ChurchDetailsPage> createState() => _ChurchDetailsPageState();
}

class _ChurchDetailsPageState extends State<ChurchDetailsPage> {
  /// The open photo header's height, from the screen's size at the last build.
  double _headerHeight = 0;

  /// Between two columns of sections: they overlap in the cards' side
  /// margins ([SectionCard.margin], `l` each), so that the cards stand `s`
  /// apart across, as they do down (DESIGN.md TK2).
  static const double _columnGap = Spacing.s - 2 * Spacing.l;

  /// The Megközelítés map's shape: as wide as its card, 3:2.
  static const double _mapAspectRatio = 3 / 2;

  /// The most of the screen's height the Megközelítés map takes, so a wide
  /// window still shows the text around it.
  static const double _mapMaxHeightShare = 1 / 2;

  /// The Megközelítés map's height at [width] on a screen of [screen]: a
  /// fixed height would be a thin strip of the map in a wide window.
  static double _mapHeightFor(double width, Size screen) =>
      min(width / _mapAspectRatio, screen.height * _mapMaxHeightShare);

  ChurchPageData? _data;
  late final DateTime _today = _midnightToday();

  /// The header's scrolling, which tells whether the photo is still under
  /// the title bar.
  final ScrollController _header = ScrollController();

  /// True while the photo stands under the back button and the status bar,
  /// which then need the photo's own colours to be seen (KO19).
  bool _photoUnderBar = true;

  var isFavorite = false;

  @override
  void initState() {
    super.initState();
    _header.addListener(_headerScrolled);
    loadMasses();
    isFavorite = Provider.of<FavoritesService>(
      context,
      listen: false,
    ).isFavorite(widget.church.id);
  }

  @override
  void dispose() {
    _header.dispose();
    super.dispose();
  }

  void _headerScrolled() {
    final under = _isPhotoUnderBar();
    if (under != _photoUnderBar) setState(() => _photoUnderBar = under);
  }

  /// The header collapses fully once it has scrolled by all but the toolbar;
  /// before the first layout it is open.
  bool _isPhotoUnderBar() =>
      !_header.hasClients || _header.offset < _headerHeight - kToolbarHeight;

  ChurchDetails? get _details => _data?.church;

  List<List<CachedMass>> get _masses => _data?.massesByDay ?? const [];

  @override
  Widget build(BuildContext context) {
    // A resized or turned screen rebuilds with a new height, and the same
    // scroll offset may then be on the other side of the collapse.
    _headerHeight = ChurchPhotoHeader.heightFor(MediaQuery.sizeOf(context));
    _photoUnderBar = _isPhotoUnderBar();
    return Scaffold(
      body: NestedScrollView(
        controller: _header,
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          final onPhoto = _photoUnderBar;
          return <Widget>[
            SliverAppBar(
              expandedHeight: _headerHeight,
              floating: false,
              pinned: true,
              leading: onPhoto ? _backOverPhoto(context) : null,
              systemOverlayStyle: onPhoto ? SystemUiOverlayStyle.light : null,
              flexibleSpace: FlexibleSpaceBar(
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

  /// The back button while the photo is under it: the title bar's own
  /// colour would vanish on a dark photo, so it stands on a dark disc
  /// (KO19). Null where there is nowhere to go back to.
  Widget? _backOverPhoto(BuildContext context) {
    if (!(ModalRoute.of(context)?.impliesAppBarDismissal ?? false)) {
      return null;
    }
    final colors = Theme.of(context).extension<MiserendColors>()!;
    return Center(
      child: BackButton(
        style: IconButton.styleFrom(
          backgroundColor: colors.photoScrim,
          foregroundColor: colors.onPhoto,
        ),
      ),
    );
  }

  /// Every section of the page, in reading order.
  Widget _sections() {
    return ContentColumns(
      padding: const EdgeInsets.only(bottom: Spacing.xl),
      gap: _columnGap,
      builder:
          (context, padding, columns) => ListView(
            padding: padding,
            children: [
              // The masses stand across every column: the day strip scrolls
              // sideways, and the width shows more of its days.
              _churchName(),
              _actionButtons(),
              _massCard(),
              _dayStrip(),
              ..._topics(columns),
              _updatedFooter(),
            ],
          ),
    );
  }

  /// The sections under the masses, by topic: the other occasions, where the
  /// church is and how to reach it, and what else there is to know. Each
  /// topic has a column of its own while there are enough of them; a topic
  /// with nothing to show leaves no empty column, and of three topics in two
  /// columns the last goes under the shorter (DESIGN.md EL3).
  List<Widget> _topics(int columns) {
    final topics =
        [
          [
            ..._adorationSection(),
            if (_data?.confessionLive ?? false) const ConfessionTile(),
          ],
          [_mapCard(), ..._contactSection()],
          _infoTiles(),
        ].where((topic) => topic.isNotEmpty).toList();
    if (columns == 1 || topics.length == 1) {
      return [for (final topic in topics) ...topic];
    }

    Widget column(List<Widget> topic) =>
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: topic);
    if (topics.length <= columns) {
      return [
        CardColumns(gap: _columnGap, columns: topics.map(column).toList()),
      ];
    }
    return [
      CardColumns(
        gap: _columnGap,
        columns: [column(topics[0]), column(topics[1])],
        tail: column(topics[2]),
      ),
    ];
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
      padding: const EdgeInsets.fromLTRB(
        Spacing.l,
        Spacing.l,
        Spacing.l,
        Spacing.s,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(name, style: Theme.of(context).textTheme.titleLarge),
          if (commonName.isNotEmpty)
            Text(
              commonName,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.apply(color: _secondaryText),
            ),
          if (address.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.s),
              child: InkWell(
                onTap: _showLocationOnMap,
                child: Row(
                  children: [
                    Icon(Icons.place_rounded, color: _secondaryText),
                    const SizedBox(width: Spacing.s),
                    Expanded(
                      child: Text(
                        address,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.apply(color: _secondaryText),
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

  /// Secondary text and its icons (DESIGN.md SZ5, IK4).
  Color get _secondaryText => Theme.of(context).colorScheme.onSurfaceVariant;

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
      padding: const EdgeInsets.symmetric(vertical: Spacing.s),
      // Wraps rather than overflows on a narrow screen with large text.
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: Spacing.xl,
        runSpacing: Spacing.s,
        children: [
          _actionButton(
            icon:
                isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
            // Like any icon, `primary` only when selected (IK4).
            iconColor:
                isFavorite
                    ? Theme.of(context).colorScheme.primary
                    : _secondaryText,
            label: 'Kedvencekhez',
            onPressed: _toggleFavorites,
          ),
          _reportButton(),
        ],
      ),
    );
  }

  /// Greyed out while the page marks its data as not live: a report could not
  /// get through then either (CONTEXT.md, „Hibajelentés"). Only a known
  /// failure blocks it, the one the user sees, so it comes back by itself
  /// once a retry succeeds.
  Widget _reportButton() {
    final blocked = _data?.failure != null;
    // The disabled button lets the tap through, so the explanation can catch
    // it; the button itself greys out as any disabled button does.
    return GestureDetector(
      onTap: blocked ? _explainReportBlocked : null,
      child: _actionButton(
        icon: Icons.error_outline_rounded,
        label: 'Hibajelentés',
        onPressed: blocked ? null : _openReport,
      ),
    );
  }

  /// A button with its icon above its label; colours are the text button's
  /// own, `primary` and its disabled look (DESIGN.md SZ4), unless [iconColor]
  /// says otherwise.
  Widget _actionButton({
    required IconData icon,
    Color? iconColor,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return TextButton(
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: Spacing.s,
        children: [Icon(icon, color: iconColor), Text(label)],
      ),
    );
  }

  void _explainReportBlocked() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Hibát jelenteni csak kapcsolat mellett lehet. Amint a miserend.hu '
          'újra elérhető, a gomb magától visszajön.',
        ),
      ),
    );
  }

  void _openReport() {
    final data = _data;
    // Not before the cache read has answered: until then there is no date
    // for the data the report would be about.
    if (data == null) return;
    pushMiserendTaskFlow<void>(
      context,
      (_) => ReportProblemPage(
        churchId: widget.church.id,
        churchName: _details?.name ?? widget.church.name ?? '',
        // Null only when not even the bootstrap import recorded a date; the
        // API requires one, and today is the nearest truth.
        dataAsOf: data.dataAsOf ?? _today,
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

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Ma', style: Theme.of(context).textTheme.sectionTitle),
          _todayMasses(),
          if (note.isNotEmpty) ...[
            const SizedBox(height: Spacing.s),
            ExpandableInfoTile(
              title: 'Megjegyzés a miserendhez',
              text: note,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.apply(color: _secondaryText),
            ),
          ],
        ],
      ),
    );
  }

  /// What an empty day says: where the information is missing from. Within
  /// a response's reach miserend.hu holds nothing for it; past it, nothing
  /// has been downloaded for it (CONTEXT.md, „Üres nap").
  String _missingInformation(int offset) {
    final fresh = _data?.isFresh(offset) ?? false;
    return switch ((offset == 0, fresh)) {
      (true, true) => 'Mára a miserend.hu-n nincs információ',
      (true, false) => 'Mára nincs letöltött információ',
      (false, true) => 'Erre a napra a miserend.hu-n nincs információ',
      (false, false) => 'Erre a napra nincs letöltött információ',
    };
  }

  /// Today's chips, or a sentence saying where the information is missing
  /// from: the app never knows that no mass is held.
  Widget _todayMasses() {
    final masses = _masses.isEmpty ? const <CachedMass>[] : _masses[0];

    if (masses.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: Spacing.s),
        child: Text(
          _missingInformation(0),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.apply(color: _secondaryText),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: Spacing.s),
      child: Wrap(
        spacing: Spacing.s,
        runSpacing: Spacing.s,
        // A chip that opens something takes taps on more room than it is
        // drawn on (AM3); the chips beside it stand in line with its middle.
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [for (final mass in masses) _timeChip(mass)],
      ),
    );
  }

  TimeChip _timeChip(CachedMass mass) {
    final meaningful = MassInfo.isMeaningful(mass.info);
    return TimeChip(
      time: TimeOfDay.fromDateTime(mass.time),
      ongoing: isOngoingStart(mass.time, widget.clock()),
      hasInfo: meaningful,
      onTap: meaningful ? () => MassInfo.show(context, mass) : null,
    );
  }

  /// One card for every day from tomorrow to the end of the loaded window,
  /// an empty one included, so that a gap in the schedule shows as one
  /// rather than hiding (#79). The cards stretch to the tallest and stand in
  /// line at the top.
  Widget _dayStrip() {
    // A church gone from miserend.hu has no schedule left to show a gap in.
    if (_masses.length < 2 || (_data?.churchGone ?? false)) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // With each card's own margin, the first and last card stand the
      // screen edge's distance in, in line with the sections (TK2).
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.l - Spacing.xs,
        vertical: Spacing.xs,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var offset = 1; offset < _masses.length; offset++)
              _masses[offset].isEmpty
                  ? _emptyDayCard(offset)
                  : _massDayCard(offset),
          ],
        ),
      ),
    );
  }

  /// A day card's least width at the current text size.
  double get _dayCardWidth =>
      MediaQuery.textScalerOf(context).scale(ChurchDetailsPage.dayCardMinWidth);

  /// The weekday or "Holnap" over the date, as every day card starts.
  List<Widget> _dayHeading(DateTime day, {Color? dateColor}) => [
    Text(
      DayLabel.forDate(day, _today),
      style: Theme.of(context).textTheme.titleLarge,
    ),
    Text(
      DayLabel.date.format(day),
      style: Theme.of(context).textTheme.bodyMedium?.apply(color: dateColor),
    ),
    const SizedBox(height: Spacing.s),
  ];

  Widget _massDayCard(int dayOffset) {
    return Card(
      // Half the gap between cards on either side (TK2).
      margin: const EdgeInsets.symmetric(horizontal: Spacing.xs),
      child: ConstrainedBox(
        // Grows with the text, so that a short day's card is not a sliver at
        // any text size.
        constraints: BoxConstraints(minWidth: _dayCardWidth),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._dayHeading(_today.addCalendarDays(dayOffset)),
              // On one line, so that a day with many masses grows wider, not
              // taller; the strip scrolls sideways for a wide one. The line
              // keeps a tappable chip's room (AM3) on a day without one too.
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: kMinInteractiveDimension,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: Spacing.s,
                  children: [
                    for (final mass in _masses[dayOffset]) _timeChip(mass),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A day the app knows no mass for: outlined, on the page's own colour, so
  /// that it reads as a gap rather than as the strip's loudest card (SZ4,
  /// KO1). It shows only its day: a run of empty days each saying where the
  /// information is missing from would crowd the strip (#81). Only the screen
  /// reader says it.
  Widget _emptyDayCard(int dayOffset) {
    final colors = Theme.of(context).colorScheme;
    final day = _today.addCalendarDays(dayOffset);
    // M3's outlined card, drawn here: `Card.outlined` would still take the
    // theme's colour and elevation.
    return Card(
      // Half the gap between cards on either side (TK2).
      margin: const EdgeInsets.symmetric(horizontal: Spacing.xs),
      color: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(Radii.m)),
        side: BorderSide(color: colors.outlineVariant),
      ),
      // One unit, in the order it reads (AM5).
      child: Semantics(
        label:
            '${DayLabel.forDate(day, _today)}, '
            '${DayLabel.date.format(day)}, ${_missingInformation(dayOffset)}',
        excludeSemantics: true,
        child: ConstrainedBox(
          // At least a day card's least width, as a mass day's card.
          constraints: BoxConstraints(minWidth: _dayCardWidth),
          child: Padding(
            padding: const EdgeInsets.all(Spacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _dayHeading(day, dateColor: _secondaryText),
            ),
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
      padding: const EdgeInsets.fromLTRB(
        Spacing.l,
        Spacing.l,
        Spacing.l,
        Spacing.s,
      ),
      child: Text(
        'Frissítve: ${DayLabel.date.format(updatedAt)}',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.apply(color: _secondaryText),
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
          // A picture of where the church is, read out as the button it is
          // (AM5).
          Semantics(
            button: true,
            label: 'Megnyitás térképalkalmazásban',
            child: GestureDetector(
              onTap: _showLocationOnMap,
              child: ExcludeSemantics(
                child: LayoutBuilder(
                  builder:
                      (context, constraints) => SizedBox(
                        height: _mapHeightFor(
                          constraints.maxWidth,
                          MediaQuery.sizeOf(context),
                        ),
                        child: MiserendMap(
                          interactive: false,
                          initialCenter: _location(),
                          initialZoom: 17,
                          compactAttribution: true,
                          apiKey: const String.fromEnvironment('CARTO_API_KEY'),
                          markers: [
                            MiserendMapMarker(
                              id: widget.church.id,
                              point: _location(),
                            ),
                          ],
                        ),
                      ),
                ),
              ),
            ),
          ),
          if (gettingThere.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.s),
              child: ExpandableInfoTile(text: gettingThere),
            ),
          const Padding(
            padding: EdgeInsets.only(top: Spacing.s),
            child: Divider(height: 1),
          ),
          Semantics(
            button: true,
            // Taps on the whole line, at least 48 tall (AM3), with the touch
            // feedback a button gives (PL2).
            child: InkWell(
              onTap: _showDirectionsOnMap,
              child: Padding(
                padding: const EdgeInsets.only(top: Spacing.s),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: kMinInteractiveDimension,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'ÚTVONAL',
                      style: Theme.of(context).textTheme.titleMedium!.apply(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
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
    final now = widget.clock();
    return DateTime(now.year, now.month, now.day);
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
