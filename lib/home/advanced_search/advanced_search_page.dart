import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/home/advanced_search/advanced_search_loader.dart';
import 'package:miserend/home/advanced_search/widgets/result_count_badge.dart';
import 'package:miserend/home/churches/church_card.dart';
import 'package:miserend/home/widgets/section_bar.dart';
import 'package:miserend/location_provider.dart';
import 'package:miserend/widgets/language_flag.dart';
import 'package:miserend/widgets/list_status_view.dart';
import 'package:miserend/widgets/offline_notice.dart';
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
  });

  final String name;
  final String city;
  final String? language;
  final DayChoice? dayChoice;
  final DateTime? date;
  final bool wholeDay;
  final TimeOfDay from;
  final TimeOfDay until;
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

  /// How close to the end of the list the next page is asked for, so that it
  /// has usually arrived by the time the user gets there.
  static const double _loadAhead = 2 * _rowExtent;

  /// A card with the room its [Card] margin takes around it.
  static const double _rowExtent = ChurchCard.height + 8;
  static const double _listPadding = 8;

  /// The list end's spinner and the room around it.
  static const double _spinnerSize = 24;
  static const double _listEndPadding = 16;

  /// About five cities, leaving the fields below in sight.
  static const double _citySuggestionsMaxHeight = 240;

  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  final TextEditingController _city = TextEditingController();
  final FocusNode _cityFocus = FocusNode();
  final ScrollController _scroll = ScrollController();

  String? _language;
  DayChoice? _dayChoice;
  DateTime? _date;
  bool _wholeDay = true;
  TimeOfDay _from = _defaultFrom;
  TimeOfDay _until = _defaultUntil;

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

  @override
  void initState() {
    super.initState();
    _name.addListener(_conditionsChanged);
    _city.addListener(_conditionsChanged);
    _scroll.addListener(_fillScreen);
    _findPosition();
  }

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _cityFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// The Search button depends on the name and the city being filled in.
  void _conditionsChanged() => setState(() {});

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

  _Conditions get _conditions => _Conditions(
    name: _name.text,
    city: _city.text,
    language: _language,
    dayChoice: _dayChoice,
    date: _date,
    wholeDay: _wholeDay,
    from: _from,
    until: _until,
  );

  AdvancedSearchCriteria _criteriaOf(_Conditions conditions) {
    final day = _dayOf(conditions.dayChoice);
    final window = day != null && !conditions.wholeDay;
    // A window typed back to front means the same hours.
    final (from, until) =
        _minutes(conditions.from) <= _minutes(conditions.until)
            ? (conditions.from, conditions.until)
            : (conditions.until, conditions.from);
    return AdvancedSearchCriteria(
      name: conditions.name,
      city: conditions.city,
      language: conditions.language,
      day: day,
      from: window ? from : null,
      until: window ? until : null,
      position: _position,
    );
  }

  void _search() {
    FocusScope.of(context).unfocus();
    final conditions = _conditions;
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
      _expanded = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fillScreen());
  }

  void _expand() => setState(() => _expanded = true);

  bool get _hasMore => _pages.isEmpty || _pages.last.hasMore;

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
    if (!_scroll.hasClients || _scroll.position.extentAfter < _loadAhead) {
      _loadNext();
    }
  }

  /// Loads the pages shown so far again, for the banner's retries: they swap
  /// in together, so the list does not jump while it heals.
  Future<void> _retry() async {
    final criteria = _criteria;
    if (criteria == null || _loading) return;
    final loadId = _loadId;
    final count = _pages.length;
    setState(() => _loading = true);
    final pages = <AdvancedSearchResultPage>[];
    for (var page = 0; page < count; page++) {
      pages.add(await _loader.loadPage(criteria, page));
      if (!mounted || loadId != _loadId) return;
    }
    setState(() {
      _pages
        ..clear()
        ..addAll(pages);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black12,
      appBar: SectionBar.title('Részletes kereső', onBack: widget.onClose),
      body: _expanded ? _form() : _results(),
    );
  }

  // ---- Conditions --------------------------------------------------------

  Widget _form() {
    final canSearch = _criteriaOf(_conditions).canSearch;
    final day = _dayOf(_dayChoice);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        SectionCard(
          title: 'Feltételek',
          trailing:
              _applied == null
                  ? null
                  : IconButton(
                    icon: const Icon(Icons.keyboard_arrow_up),
                    tooltip: 'Összecsukás',
                    onPressed: _collapse,
                  ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Templom neve'),
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _cityFocus.requestFocus(),
                onTapOutside: _unfocus,
              ),
              const SizedBox(height: 12),
              _cityField(),
              const SizedBox(height: 8),
              _languageRow(),
              const SizedBox(height: 8),
              Text('Nap', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              _dayChips(),
              if (day != null) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Egész nap'),
                  value: _wholeDay,
                  onChanged: (value) => setState(() => _wholeDay = value),
                ),
                if (!_wholeDay)
                  Row(
                    children: [
                      Expanded(
                        child: _timeField('-tól', _from, (t) => _from = t),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _timeField('-ig', _until, (t) => _until = t),
                      ),
                    ],
                  ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: canSearch ? _search : null,
                child: const Text('Keresés'),
              ),
              if (!canSearch)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _locating
                        ? 'Adj meg nevet vagy települést, vagy várd meg, '
                            'amíg a helyzeted meghatározzuk.'
                        : 'Adj meg nevet vagy települést: a helyzeted nem '
                            'ismert, így a környékeden nem kereshetünk.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ),
            ],
          ),
        ),
      ],
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
                elevation: 4,
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
                          leading: const Icon(Icons.location_city),
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
              ? const Icon(Icons.translate)
              : LanguageFlag(language),
      title: Text(
        'Nyelv: ${language == null ? 'bármelyik' : languageName(language)}',
      ),
      trailing: const Icon(Icons.arrow_drop_down),
      onTap: _pickLanguage,
    );
  }

  /// „Bármelyik" is the empty code, told apart from closing the sheet.
  Future<void> _pickLanguage() async {
    FocusScope.of(context).unfocus();
    final languages = await _loader.languages();
    if (!mounted) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder:
          (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: const Icon(Icons.translate),
                  title: const Text('Bármelyik'),
                  onTap: () => Navigator.of(context).pop(''),
                ),
                for (final code in languages)
                  ListTile(
                    leading: LanguageFlag(code),
                    title: Text(languageName(code)),
                    onTap: () => Navigator.of(context).pop(code),
                  ),
              ],
            ),
          ),
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
      spacing: 8,
      children: [
        for (final MapEntry(key: choice, value: label) in labels.entries)
          ChoiceChip(
            label: Text(label),
            selected: _dayChoice == choice,
            onSelected: (_) => _chooseDay(choice),
          ),
      ],
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
      final picked = await showDatePicker(
        context: context,
        initialDate: _date ?? today,
        firstDate: today,
        lastDate: DateTime(today.year, today.month, today.day + _pickableDays),
        helpText: 'Nap',
        cancelText: 'Mégse',
        confirmText: 'Kész',
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

  Widget _timeField(
    String label,
    TimeOfDay value,
    void Function(TimeOfDay) set,
  ) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: value,
          cancelText: 'Mégse',
          confirmText: 'Kész',
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(alwaysUse24HourFormat: true),
                child: child!,
              ),
        );
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
    final failure = _pages.map((page) => page.failure).nonNulls.firstOrNull;
    return Column(
      children: [
        _Summary(text: _summary(), onTap: _expand),
        if (failure != null)
          OfflineBanner(
            failure: failure,
            asOf: _pages.last.dataAsOf,
            onRetry: _retry,
          ),
        Expanded(child: _list()),
      ],
    );
  }

  Widget _list() {
    final churches = [for (final page in _pages) ...page.churches];
    if (churches.isEmpty && (_loading || _hasMore)) {
      // An empty page with more to come is asked for on the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => _fillScreen());
      return const LoadingView(message: 'Keresés...');
    }
    if (churches.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MessageView(message: 'Nincs találat'),
            OutlinedButton(
              onPressed: _expand,
              child: const Text('Feltételek módosítása'),
            ),
          ],
        ),
      );
    }

    final last = _pages.last;
    final position = _criteria?.distanceOrderFrom;
    return Stack(
      children: [
        CustomScrollView(
          // Folding the conditions without a search puts the list back where
          // it was.
          key: const PageStorageKey('results'),
          controller: _scroll,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                _listPadding,
                _listPadding,
                _listPadding,
                0,
              ),
              sliver: SliverFixedExtentList(
                itemExtent: _rowExtent,
                delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                      ChurchCard(entry: churches[index], position: position),
                  childCount: churches.length,
                ),
              ),
            ),
            SliverToBoxAdapter(child: _listEnd(last)),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 16,
          child: Center(
            child: ResultCountBadge(
              controller: _scroll,
              rowExtent: _rowExtent,
              topPadding: _listPadding,
              shown: churches.length,
              found: last.found,
              foundIsFinal: last.foundIsFinal,
            ),
          ),
        ),
      ],
    );
  }

  /// The spinner only while a page is on its way; the space it takes is kept
  /// between pages, so the end of the list does not jump.
  Widget _listEnd(AdvancedSearchResultPage last) {
    if (!_loading && last.hasMore) {
      return const SizedBox(height: 2 * _listEndPadding + _spinnerSize);
    }
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(_listEndPadding),
        child: Center(
          child: SizedBox.square(
            dimension: _spinnerSize,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        'Nincs több találat · ${last.found} találat',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.grey),
      ),
    );
  }

  /// „Pécs · vasárnap 9–12 · latin": what the results were found by.
  String _summary() {
    final applied = _applied!;
    final name = applied.name.trim();
    final city = applied.city.trim();
    final day = _dayOf(applied.dayChoice);
    final language = applied.language;
    return [
      if (name.isNotEmpty) name,
      if (city.isNotEmpty) city,
      if (name.isEmpty && city.isEmpty) 'a közelben',
      if (day != null)
        [
          applied.dayChoice == DayChoice.date
              ? shortDate(day)
              : applied.dayChoice!.label.toLowerCase(),
          if (!applied.wholeDay)
            '${_shortTime(applied.from)}–${_shortTime(applied.until)}',
        ].join(' '),
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
    return Card(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.filter_list, color: Colors.black54),
              const SizedBox(width: 12),
              Expanded(child: Text(text)),
              const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
            ],
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
