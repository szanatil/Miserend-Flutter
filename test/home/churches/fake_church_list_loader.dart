import 'dart:async';
import 'dart:collection';

import 'package:miserend/api/api_result.dart';
import 'package:miserend/database/cache/church_list_entry.dart';
import 'package:miserend/home/churches/church_list_loader.dart';

/// Answers [load] with the cache's rows and each [refresh] with the next
/// refresh answer: a [ChurchList], or a completer to wait on. With no refresh
/// answers, a refresh succeeds and changes nothing.
class FakeChurchListLoader extends ChurchListLoader {
  FakeChurchListLoader(List<Object> cached, {List<Object> refreshed = const []})
    : _cached = Queue.of(cached),
      _refreshed = Queue.of(refreshed);

  final Queue<Object> _cached;
  final Queue<Object> _refreshed;
  int reads = 0;
  int refreshes = 0;
  final List<ChurchListQuery> queries = [];

  static Object _next(Queue<Object> answers) =>
      answers.length > 1 ? answers.removeFirst() : answers.first;

  @override
  Future<ChurchList> load(ChurchListQuery query) async {
    reads++;
    queries.add(query);
    final answer = _next(_cached);
    if (answer is Completer<List<ChurchListEntry>>) {
      return listOf(await answer.future);
    }
    return listOf(answer as List<ChurchListEntry>);
  }

  @override
  Future<ChurchList> refresh(
    ChurchListQuery query,
    List<ChurchListEntry> shown,
  ) async {
    refreshes++;
    if (_refreshed.isEmpty) return listOf(shown);
    final answer = _next(_refreshed);
    if (answer is Completer<ChurchList>) return answer.future;
    final list = answer as ChurchList;
    // A failed refresh keeps what is shown, as the real loader does.
    return list.failure == null
        ? list
        : ChurchList(
          churches: shown,
          failure: list.failure,
          dataAsOf: list.dataAsOf,
        );
  }
}

ChurchList listOf(
  List<ChurchListEntry> churches, {
  ApiFailure? failure,
  DateTime? dataAsOf,
}) => ChurchList(churches: churches, failure: failure, dataAsOf: dataAsOf);
