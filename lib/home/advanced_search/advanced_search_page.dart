import 'dart:math';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:miserend/database/cache/church_list_entry.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/home/advanced_search/advanced_search_loader.dart';
import 'package:miserend/home/advanced_search/widgets/interrupted_search_banner.dart';
import 'package:miserend/home/advanced_search/widgets/result_counter.dart';
import 'package:miserend/home/churches/church_card.dart';
import 'package:miserend/home/widgets/section_bar.dart';
import 'package:miserend/location_provider.dart';
import 'package:miserend/mass_kind.dart';
import 'package:miserend/theme/adaptive.dart';
import 'package:miserend/theme/miserend_theme.dart';
import 'package:miserend/theme/tokens.dart';
import 'package:miserend/widgets/card_columns.dart';
import 'package:miserend/widgets/content_width.dart';
import 'package:miserend/widgets/language_flag.dart';
import 'package:miserend/widgets/list_status_view.dart';
import 'package:miserend/widgets/section_card.dart';
import 'package:provider/provider.dart';

/// The day buttons of the Részletes kereső, with their label on the chip and
/// in the summary; a picked date is written out instead.
enum DayChoice {
  today('Ma'),
  tomorrow('Holnap'),
  sunday('Vasárnap'),
  date('Dátum…');

  const DayChoice(this.label);

  final String label;
}

/// The occasion categories' chips, with their label on the chip and in the
/// summary.
const Map<OccasionCategory, (String chip, String summary)> _categoryLabels = {
  OccasionCategory.mass: ('Mise', 'mise'),
  OccasionCategory.adoration: ('Szentségimádás', 'szentségimádás'),
  OccasionCategory.confession: ('Gyóntatás', 'gyóntatás'),
  OccasionCategory.other: ('Egyéb', 'egyéb imaalkalom'),
};

/// What the summary says the search by the position alone looked through
/// (spec 0010, „Oldal"), and what a ring's end says it found nothing more in.
const Map<SearchRing, String> _ringLabels = {
  SearchRing.within25Km: '25 km-en belül',
  SearchRing.within100Km: '100 km-en belül',
  SearchRing.country: 'egész országban',
};

/// What the conditions' form holds, kept so that closing it without a search
/// can put back the conditions the results were found by.
class _Conditions {
  const _Conditions({
    required this.name,
    required this.city,
    required this.language,
    required this.dayChoice,
    required this.date,
    required this.wholeDay,
    required this.from,
    required this.until,
    required this.categories,
  });

  final String name;
  final String city;
  final String? language;
  final DayChoice? dayChoice;
  final DateTime? date;
  final bool wholeDay;
  final TimeOfDay from;
  final TimeOfDay until;
  final Set<OccasionCategory> categories;
}

/// The Részletes kereső (CONTEXT.md, „Részletes kereső"; spec 0010): the
/// conditions above, the churches meeting all of them below. It opens in a
/// tab's place, so the search bar and the navigation stay.
class AdvancedSearchPage extends StatefulWidget {
  const AdvancedSearchPage({
    super.key,
    this.initialName = '',
    required this.onClose,
    this.loader,
    this.location,
    this.clock = DateTime.now,
  });

  /// What the search bar held when the page was opened.
  final String initialName;

  /// Closes the page, back to the tab.
  final VoidCallback onClose;

  /// Injected by tests; the page builds its own otherwise.
  final AdvancedSearchLoader? loader;

  /// Injected by tests; the page builds its own otherwise.
  final LocationProvider? location;

  final DateTime Function() clock;

  @override
  State<AdvancedSearchPage> createState() => _AdvancedSearchPageState();
}

class _AdvancedSearchPageState extends State<AdvancedSearchPage> {
  late final AdvancedSearchLoader _loader =
      widget.loader ??
      AdvancedSearchLoader(
        onChurchesGone:
            Provider.of<FavoritesService>(context, listen: false).removeAll,
      );
  late final LocationProvider _location = widget.location ?? LocationProvider();

  /// The furthest ahead a date can be picked. Nothing was agreed on it; three
  /// months covers planning a trip (spec 0010, „Further Notes").
  static const int _pickableDays = 90;

  /// The window offered once „Egész nap" is switched off, to be adjusted: a
  /// morning, when most Sunday masses are held.
  static const TimeOfDay _defaultFrom = TimeOfDay(hour: 8, minute: 0);
  static const TimeOfDay _defaultUntil = TimeOfDay(hour: 12, minute: 0);

  static const double _listPadding = Spacing.s;

  /// The list end's spinner and the room around it.
  static const double _spinnerSize = 24;
  static const double _listEndPadding = Spacing.l;

  /// About five cities, leaving the fields below in sight.
  static const double _citySuggestionsMaxHeight = 240;

  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  final TextEditingController _city = TextEditingController();
  final FocusNode _cityFocus = FocusNode();
  final ScrollController _scroll = ScrollController();

  /// The results' sliver list, which the count reads the cards seen off.
  final GlobalKey _resultList = GlobalKey();

  String? _language;
  DayChoice? _dayChoice;
  DateTime? _date;
  bool _wholeDay = true;
  TimeOfDay _from = _defaultFrom;
  TimeOfDay _until = _defaultUntil;
  Set<OccasionCategory> _categories = AdvancedSearchCriteria.defaultCategories;

  LatLng? _position;

  /// Whether the position is still being found, which may yet allow a search
  /// with nothing typed.
  bool _locating = true;

  /// Whether the conditions fill the page; they fold away after a search.
  bool _expanded = true;

  /// The conditions of the last search, and what was asked of the loader.
  _Conditions? _applied;
  AdvancedSearchCriteria? _criteria;

  final List<AdvancedSearchResultPage> _pages = [];
  bool _loading = false;

  /// Bumped per search so that a slow page cannot land in a newer search.
  int _loadId = 0;

  /// Whether a connection check is on its way, so that it is not asked
  /// twice.
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(_conditionsChanged);
    _city.addListener(_conditionsChanged);
    _scroll.addListener(_fillScreen);
    _loader.lastFailure.addListener(_conditionsChanged);
    _findPosition();
  }

  @override
  void dispose() {
    _loader.lastFailure.removeListener(_conditionsChanged);
    _name.dispose();
    _city.dispose();
    _cityFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// The Search button depends on the name and the city being filled in,
  /// the day chips on the connection.
  void _conditionsChanged() => setState(() {});

  /// Whether the day condition is offered: not while the app's last API call
  /// got no answer, as the cached days may be out of date (CONTEXT.md,
  /// „Részletes kereső").
  bool get _online => _loader.lastFailure.value == null;

  Future<void> _checkConnection() async {
    if (_checking) return;
    setState(() => _checking = true);
    await _loader.checkConnection();
    if (!mounted) return;
    setState(() => _checking = false);
  }

  Future<void> _findPosition() async {
    switch (await _location.currentPosition()) {
      case PositionFound(:final position):
        if (!mounted) return;
        setState(() {
          _position = LatLng(position.latitude, position.longitude);
          _locating = false;
        });
      case PositionUnavailable():
        if (!mounted) return;
        setState(() => _locating = false);
    }
  }

  DateTime get _today {
    final now = widget.clock();
    return DateTime(now.year, now.month, now.day);
  }

  /// On a Sunday, „Vasárnap" is today, as the details page's „Ma" is.
  DateTime? _dayOf(DayChoice? choice) {
    final today = _today;
    return switch (choice) {
      null => null,
      DayChoice.today => today,
      DayChoice.tomorrow => DateTime(today.year, today.month, today.day + 1),
      DayChoice.sunday => DateTime(
        today.year,
        today.month,
        today.day + (DateTime.sunday - today.weekday),
      ),
      DayChoice.date => _date,
    };
  }

  /// What the form holds; a day chosen while the day chips are off is none.
  _Conditions get _conditions => _Conditions(
    name: _name.text,
    city: _city.text,
    language: _language,
    dayChoice: _online ? _dayChoice : null,
    date: _date,
    wholeDay: _wholeDay,
    from: _from,
    until: _until,
    categories: _categories,
  );

  AdvancedSearchCriteria _criteriaOf(_Conditions conditions) {
    final day = _dayOf(conditions.dayChoice);
    final window = day != null && !conditions.wholeDay;
    return AdvancedSearchCriteria(
      name: conditions.name,
      city: conditions.city,
      language: conditions.language,
      day: day,
      from: window ? conditions.from : null,
      until: window ? conditions.until : null,
      categories: conditions.categories,
      position: _position,
    );
  }

  void _search() => _searchBy(_conditions);

  /// [conditions]' search, from its start.
  void _searchBy(_Conditions conditions) {
    FocusScope.of(context).unfocus();
    setState(() {
      _loadId++;
      _applied = conditions;
      _criteria = _criteriaOf(conditions);
      _expanded = false;
      _pages.clear();
      _loading = false;
    });
    _loadNext();
  }

  /// Folds the conditions away without a search: what was changed is let go,
  /// so that the summary keeps saying what the results were found by.
  void _collapse() {
    final applied = _applied;
    if (applied == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _name.text = applied.name;
      _city.text = applied.city;
      _language = applied.language;
      _dayChoice = applied.dayChoice;
      _date = applied.date;
      _wholeDay = applied.wholeDay;
      _from = applied.from;
      _until = applied.until;
      _categories = applied.categories;
      _expanded = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fillScreen());
  }

  void _expand() => setState(() => _expanded = true);

  /// Whether there are pages left to ask for: none once the search stopped,
  /// until it is started over (CONTEXT.md, „Részletes kereső"), and none past
  /// a ring's end until the user asks for the next ring.
  bool get _hasMore {
    final last = _pages.lastOrNull;
    if (last == null) return true;
    if (last.failure != null) return false;
    return last.hasMore || last.ring != _criteria?.searchRing;
  }

  /// The ring the user may go on to, at the end of the one looked through;
  /// null while there is more of it, and past the last.
  SearchRing? get _widerRing {
    final last = _pages.lastOrNull;
    if (last == null || _loading || _hasMore || last.failure != null) {
      return null;
    }
    return last.ring?.wider;
  }

  /// „Keresés tovább": the same search in the next ring, from the page after
  /// the last one.
  void _searchFurther() {
    setState(() => _criteria = _criteria!.widened());
    _loadNext();
  }

  /// How far through its ring the search has got, while one is being looked
  /// through; null before the ring's first page is in, when its candidates
  /// are not yet counted, and for a search with no rings, which goes on as
  /// it did (#84).
  LoadingProgress? get _ringProgress {
    final last = _pages.lastOrNull;
    final ring = _criteria?.searchRing;
    if (last == null || ring == null || last.ring != ring) return null;
    return LoadingProgress(
      value: last.candidates == 0 ? 1 : last.lookedAt / last.candidates,
      caption: '${last.lookedAt} / ${last.candidates} templom átnézve',
    );
  }

  Future<void> _loadNext() async {
    final criteria = _criteria;
    if (criteria == null || _loading || !_hasMore) return;
    final loadId = _loadId;
    setState(() => _loading = true);
    final page = await _loader.loadPage(criteria, _pages.length);
    if (!mounted || loadId != _loadId) return;
    setState(() {
      _pages.add(page);
      _loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fillScreen());
  }

  /// Asks for the next page while the list does not reach below the screen
  /// — also when a page found few churches or none (spec 0010, „Betöltés").
  void _fillScreen() {
    if (!mounted || _expanded) return;
    // A screenful ahead: the next page has usually arrived by the time the
    // user gets there, however tall the cards are at the text size.
    if (!_scroll.hasClients ||
        _scroll.position.extentAfter < _scroll.position.viewportDimension) {
      _loadNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SectionBar.title('Részletes kereső', onBack: widget.onClose),
      body: _expanded ? _form() : _results(),
    );
  }

  // ---- Conditions --------------------------------------------------------

  Widget _form() {
    final canSearch = _criteriaOf(_conditions).canSearch;
    final day = _online ? _dayOf(_dayChoice) : null;
    return ContentWidth(
      padding: const EdgeInsets.symmetric(vertical: Spacing.s),
      builder:
          (context, padding) => ListView(
            padding: padding,
            children: [
              SectionCard(
                title: 'Feltételek',
                trailing:
                    _applied == null
                        ? null
                        : IconButton(
                          icon: const Icon(Icons.keyboard_arrow_up_rounded),
                          tooltip: 'Összecsukás',
                          onPressed: _collapse,
                        ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Templom neve',
                      ),
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _cityFocus.requestFocus(),
                      onTapOutside: _unfocus,
                    ),
                    const SizedBox(height: Spacing.l),
                    _cityField(),
                    const SizedBox(height: Spacing.l),
                    _languageRow(),
                    const SizedBox(height: Spacing.l),
                    Text(
                      'Nap',
                      style: Theme.of(context).textTheme.sectionTitle,
                    ),
                    const SizedBox(height: Spacing.s),
                    _dayChips(),
                    if (!_online) _offlineNote(),
                    if (day != null) ...[
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Egész nap'),
                        value: _wholeDay,
                        onChanged: (value) {
                          miserendSelectionHaptic(context);
                          setState(() => _wholeDay = value);
                        },
                      ),
                      if (!_wholeDay)
                        Row(
                          children: [
                            Expanded(
                              // The window never runs back to front: moving one
                              // end past the other takes the other along.
                              child: _timeField('-tól', _from, (t) {
                                _from = t;
                                if (_minutes(_until) < _minutes(t)) _until = t;
                              }),
                            ),
                            const SizedBox(width: Spacing.l),
                            Expanded(
                              child: _timeField('-ig', _until, (t) {
                                _until = t;
                                if (_minutes(_from) > _minutes(t)) _from = t;
                              }),
                            ),
                          ],
                        ),
                      const SizedBox(height: Spacing.l),
                      Text(
                        'Alkalom',
                        style: Theme.of(context).textTheme.sectionTitle,
                      ),
                      const SizedBox(height: Spacing.s),
                      _categoryChips(),
                    ],
                    const SizedBox(height: Spacing.l),
                    FilledButton(
                      onPressed: canSearch ? _search : null,
                      child: const Text('Keresés'),
                    ),
                    if (!canSearch)
                      Padding(
                        padding: const EdgeInsets.only(top: Spacing.s),
                        child: Text(
                          _locating
                              ? 'Adj meg nevet vagy települést, vagy várd meg, '
                                  'amíg a helyzeted meghatározzuk.'
                              : 'Adj meg nevet vagy települést: a helyzeted nem '
                                  'ismert, így a környékeden nem kereshetünk.',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
    );
  }

  void _unfocus(PointerDownEvent event) => FocusScope.of(context).unfocus();

  Widget _cityField() {
    return RawAutocomplete<String>(
      textEditingController: _city,
      focusNode: _cityFocus,
      optionsBuilder: (value) async {
        final term = value.text.trim();
        if (term.isEmpty) return const <String>[];
        return _loader.cities(term);
      },
      onSelected: (_) => FocusScope.of(context).unfocus(),
      fieldViewBuilder:
          (context, controller, focusNode, onSubmitted) => TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: const InputDecoration(labelText: 'Település'),
            textInputAction: TextInputAction.done,
            onTapOutside: _unfocus,
          ),
      optionsViewBuilder:
          (context, onSelected, options) => TextFieldTapRegion(
            child: Align(
              alignment: Alignment.topLeft,
              child: Material(
                // Set off from the form by tone, not shadow (DESIGN.md MÉ1,
                // MÉ2).
                color: Theme.of(context).colorScheme.surfaceContainer,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: _citySuggestionsMaxHeight,
                  ),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    children: [
                      for (final city in options)
                        ListTile(
                          leading: const Icon(Icons.location_city_rounded),
                          title: Text(city),
                          onTap: () => onSelected(city),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }

  Widget _languageRow() {
    final language = _language;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading:
          language == null
              ? const Icon(Icons.translate_rounded)
              : LanguageFlag(language),
      title: Text(
        'Nyelv: ${language == null ? 'bármelyik' : languageName(language)}',
      ),
      trailing: const Icon(Icons.arrow_drop_down_rounded),
      onTap: _pickLanguage,
    );
  }

  /// „Bármelyik" is the empty code, told apart from closing the sheet.
  Future<void> _pickLanguage() async {
    FocusScope.of(context).unfocus();
    final languages = await _loader.languages();
    if (!mounted) return;
    final picked = await showMiserendActionSheet<String>(
      context,
      actions: [
        const MiserendSheetAction(
          label: 'Bármelyik',
          value: '',
          leading: Icon(Icons.translate_rounded),
        ),
        for (final code in languages)
          MiserendSheetAction(
            label: languageName(code),
            value: code,
            leading: LanguageFlag(code),
          ),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() => _language = picked.isEmpty ? null : picked);
  }

  Widget _dayChips() {
    final date = _date;
    final labels = {
      for (final choice in DayChoice.values)
        choice:
            choice == DayChoice.date && _dayChoice == choice && date != null
                ? shortDate(date)
                : choice.label,
    };
    return Wrap(
      spacing: Spacing.s,
      children: [
        for (final MapEntry(key: choice, value: label) in labels.entries)
          ChoiceChip(
            label: Text(label),
            selected: _online && _dayChoice == choice,
            onSelected: _online ? (_) => _chooseDay(choice) : null,
          ),
      ],
    );
  }

  /// Why the day chips are off, and the way to try the connection again.
  Widget _offlineNote() {
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.s),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: Spacing.s,
        children: [
          Text(
            'Kapcsolat nélkül csak név, település és nyelv szerint lehet '
            'keresni.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          TextButton(
            onPressed: _checking ? null : _checkConnection,
            child: const Text('Újrapróbálom'),
          ),
        ],
      ),
    );
  }

  /// Tapping the chosen day again takes the day condition away.
  Future<void> _chooseDay(DayChoice choice) async {
    FocusScope.of(context).unfocus();
    if (_dayChoice == choice) {
      setState(() => _dayChoice = null);
      return;
    }
    if (choice == DayChoice.date) {
      final today = _today;
      final picked = await pickMiserendDate(
        context,
        initialDate: _date ?? today,
        firstDate: today,
        lastDate: DateTime(today.year, today.month, today.day + _pickableDays),
        helpText: 'Nap',
      );
      if (picked == null || !mounted) return;
      setState(() {
        _date = picked;
        _dayChoice = DayChoice.date;
      });
      return;
    }
    setState(() => _dayChoice = choice);
  }

  /// Any number of categories, at least one: the last one chosen stays on
  /// (CONTEXT.md, „Alkalom kategóriája").
  Widget _categoryChips() {
    return Wrap(
      spacing: Spacing.s,
      children: [
        for (final MapEntry(key: category, value: (label, _))
            in _categoryLabels.entries)
          FilterChip(
            label: Text(label),
            selected: _categories.contains(category),
            onSelected: (selected) {
              if (!selected && _categories.length == 1) return;
              setState(
                () =>
                    _categories =
                        selected
                            ? {..._categories, category}
                            : _categories.difference({category}),
              );
            },
          ),
      ],
    );
  }

  Widget _timeField(
    String label,
    TimeOfDay value,
    void Function(TimeOfDay) set,
  ) {
    return InkWell(
      onTap: () async {
        final picked = await pickMiserendTime(context, initialTime: value);
        if (picked == null || !mounted) return;
        setState(() => set(picked));
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(_timeText(value)),
      ),
    );
  }

  // ---- Results -----------------------------------------------------------

  Widget _results() {
    final failure = _pages.lastOrNull?.failure;
    final churches = [for (final page in _pages) ...page.churches];
    return Column(
      children: [
        _Summary(text: _summary(), onTap: _expand),
        if (failure != null)
          InterruptedSearchBanner(
            failure: failure,
            foundAny: churches.isNotEmpty,
            onRestart: () => _searchBy(_applied!),
          ),
        Expanded(child: _list(churches, stopped: failure != null)),
      ],
    );
  }

  Widget _list(List<ChurchListEntry> churches, {required bool stopped}) {
    // The strip above says the search failed; there is nothing to show.
    if (churches.isEmpty && stopped) return const SizedBox.shrink();
    if (churches.isEmpty && (_loading || _hasMore)) {
      // An empty page with more to come is asked for on the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => _fillScreen());
      return LoadingView(message: 'Keresés...', progress: _ringProgress);
    }
    if (churches.isEmpty) {
      final wider = _widerRing;
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MessageView(message: 'Nincs találat'),
              if (wider != null) ...[
                _ringEndNote(),
                const SizedBox(height: Spacing.l),
              ],
              Wrap(
                alignment: WrapAlignment.center,
                spacing: Spacing.s,
                runSpacing: Spacing.s,
                children: [
                  FilledButton.tonal(
                    onPressed: _expand,
                    child: const Text('Feltételek módosítása'),
                  ),
                  if (wider != null) _searchFurtherButton(),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final last = _pages.last;
    return ContentColumns(
      padding: const EdgeInsets.fromLTRB(Spacing.l, _listPadding, Spacing.l, 0),
      gap: CardRow.listGap,
      builder:
          (context, padding, columns) => Stack(
            children: [
              CustomScrollView(
                // Folding the conditions without a search puts the list back
                // where it was.
                key: const PageStorageKey('results'),
                controller: _scroll,
                slivers: [
                  SliverPadding(
                    padding: padding,
                    // Each card as tall as its content (DESIGN.md EL2), as
                    // tall as its row's on a wide screen (EL3).
                    sliver: SliverList(
                      key: _resultList,
                      delegate: SliverChildBuilderDelegate(
                        (context, row) => _row(churches, row, columns),
                        childCount: (churches.length / columns).ceil(),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(child: _listEnd(last)),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: Spacing.l,
                child: Center(
                  child: ResultCounter(
                    controller: _scroll,
                    list: _resultList,
                    columns: columns,
                    shown: churches.length,
                    found: last.found,
                    foundIsFinal: last.foundIsFinal,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  /// The churches of the results' [row], [columns] to a row, in their order
  /// (DESIGN.md EL3).
  Widget _row(List<ChurchListEntry> churches, int row, int columns) {
    final position = _criteria?.distanceOrderFrom;
    final first = row * columns;
    return CardRow.of(columns, [
      for (final entry in churches.sublist(
        first,
        min(first + columns, churches.length),
      ))
        ChurchCard(entry: entry, position: position, describesOccasions: true),
    ]);
  }

  /// The spinner — or how far through its ring the search has got — only
  /// while a page is on its way; the space it takes is kept between pages,
  /// so the end of the list does not jump. At a ring's end, the way on to
  /// the next.
  Widget _listEnd(AdvancedSearchResultPage last) {
    final progress = _ringProgress;
    if (progress != null && (_loading || _hasMore)) {
      // The bar keeps its own distance from the screen's edge (DESIGN.md
      // KO8), and its width centred.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: _listEndPadding),
        child: Center(
          child: Visibility.maintain(visible: _loading, child: progress),
        ),
      );
    }
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(_listEndPadding),
        child: Center(
          child: SizedBox.square(
            dimension: _spinnerSize,
            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_hasMore || last.failure != null) {
      return const SizedBox(
        height: _listEndPadding + _spinnerSize + _listEndPadding,
      );
    }
    if (_widerRing != null) {
      return Padding(
        padding: const EdgeInsets.only(top: _listEndPadding),
        child: Column(
          children: [
            _ringEndNote(),
            const SizedBox(height: Spacing.s),
            _searchFurtherButton(),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(_listEndPadding),
      child: Text(
        'Nincs több találat · ${last.found} találat',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  /// „25 km-en belül nincs több találat…": why the list stopped, and that
  /// going on may take a while (spec 0010, „Lista alja").
  Widget _ringEndNote() {
    final ring = _pages.last.ring!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.l),
      child: Text(
        '${_ringLabels[ring]} nincs több találat. A távolabbi templomok '
        'átnézése eltarthat egy ideig.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _searchFurtherButton() => TextButton(
    onPressed: _searchFurther,
    child: const Text('Keresés tovább'),
  );

  /// „Pécs · vasárnap 9–12 · szentségimádás · latin": what the results were
  /// found by; „25 km-en belül · …" by the position alone. The categories
  /// only count with a day, and are named only when they are not the
  /// default, masses alone.
  String _summary() {
    final applied = _applied!;
    final name = applied.name.trim();
    final city = applied.city.trim();
    final day = _dayOf(applied.dayChoice);
    final language = applied.language;
    return [
      if (name.isNotEmpty) name,
      if (city.isNotEmpty) city,
      // Searched by the position alone: the ring the list looked through,
      // which „Keresés tovább" widens.
      if (_criteria?.searchRing case final ring?) _ringLabels[ring]!,
      if (day != null)
        [
          applied.dayChoice == DayChoice.date
              ? shortDate(day)
              : applied.dayChoice!.label.toLowerCase(),
          if (!applied.wholeDay)
            '${_shortTime(applied.from)}–${_shortTime(applied.until)}',
        ].join(' '),
      if (day != null &&
          !setEquals(
            applied.categories,
            AdvancedSearchCriteria.defaultCategories,
          ))
        applied.categories.length == _categoryLabels.length
            ? 'minden alkalom'
            : [
              for (final MapEntry(key: category, value: (_, word))
                  in _categoryLabels.entries)
                if (applied.categories.contains(category)) word,
            ].join(', '),
      if (language != null) languageName(language),
    ].join(' · ');
  }
}

/// The folded conditions, pinned above the results: what they were found by,
/// and the way back to the conditions.
class _Summary extends StatelessWidget {
  const _Summary({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return ContentWidth(
      padding: const EdgeInsets.fromLTRB(Spacing.l, Spacing.s, Spacing.l, 0),
      builder:
          (context, margin) => Card(
            margin: margin,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(Spacing.l),
                child: Row(
                  children: [
                    Icon(Icons.filter_list_rounded, color: iconColor),
                    const SizedBox(width: Spacing.s),
                    Expanded(child: Text(text)),
                    Icon(Icons.keyboard_arrow_down_rounded, color: iconColor),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}

const List<String> _months = [
  'jan.',
  'febr.',
  'márc.',
  'ápr.',
  'máj.',
  'jún.',
  'júl.',
  'aug.',
  'szept.',
  'okt.',
  'nov.',
  'dec.',
];

/// „okt. 4.", written out by hand: `intl` has no Hungarian data loaded.
@visibleForTesting
String shortDate(DateTime day) => '${_months[day.month - 1]} ${day.day}.';

/// „9:00".
String _timeText(TimeOfDay time) =>
    '${time.hour}:${time.minute.toString().padLeft(2, '0')}';

/// „9" on the hour, „9:30" otherwise.
String _shortTime(TimeOfDay time) =>
    time.minute == 0 ? '${time.hour}' : _timeText(time);

int _minutes(TimeOfDay time) => time.hour * 60 + time.minute;
