import 'package:flutter/material.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/home/churches/church_list_loader.dart';
import 'package:miserend/home/churches/church_list_view.dart';
import 'package:miserend/widgets/list_status_view.dart';
import 'package:provider/provider.dart';

class SearchParams {
  String? city;
  String? searchTerm;

  static SearchParams fromCity(String city)
  {
    var param = SearchParams();
    param.city = city;
    return param;
  }

  static SearchParams fromSearchTerm(String searchTerm)
  {
    var param = SearchParams();
    param.searchTerm = searchTerm;
    return param;
  }

  ChurchListQuery get query => city != null
      ? SearchQuery.byCity(city!)
      : SearchQuery.byName(searchTerm!);

  @override
  String toString() {
    return city != null ? city! : searchTerm!;
  }
}

/// The churches found by name or city, drawn from the cache at once and
/// refreshed in the background (ADR-0003).
class SearchResultsPage extends StatefulWidget {
  const SearchResultsPage({super.key, required this.searchParams, this.loader});

  final SearchParams searchParams;

  /// Injected by tests; the page builds its own otherwise.
  final ChurchListLoader? loader;

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage>  with
    AutomaticKeepAliveClientMixin<SearchResultsPage>{

  late final ChurchListLoader _loader = widget.loader ??
      ChurchListLoader(
          onChurchesGone:
              Provider.of<FavoritesService>(context, listen: false).removeAll);
  late final ChurchListQuery _query = widget.searchParams.query;

  ChurchList? _list;

  /// Bumped per load so that a slow answer cannot overwrite a newer one.
  int _loadId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final list = _list;
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.searchParams.toString()),
        ),
      body: Container(
        color: Colors.black12,
        child: list == null
            ? const LoadingView(message: 'Keresés...')
            : ChurchListView(
                list: list,
                emptyMessage: 'Nincs találat',
                onRefresh: _load,
              ),
      ),
    );
  }

  /// Draws what the cache finds, then refreshes it in the background.
  /// Pull-to-refresh waits for the whole of it.
  Future<void> _load() async {
    final loadId = ++_loadId;
    bool current() => mounted && loadId == _loadId;

    final cached = await _loader.load(_query);
    if (!current()) return;
    setState(() {
      // A banner already up stays until a refresh succeeds.
      _list = ChurchList(
        churches: cached.churches,
        failure: _list?.failure,
        dataAsOf: cached.dataAsOf,
      );
    });

    final refreshed = await _loader.refresh(_query, cached.churches);
    if (!current()) return;
    setState(() => _list = refreshed);
  }

  @override
  bool get wantKeepAlive => true;
}
