import 'dart:math';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:miserend/home/churches/church_card.dart';
import 'package:miserend/home/churches/church_list_loader.dart';
import 'package:miserend/theme/tokens.dart';
import 'package:miserend/widgets/card_columns.dart';
import 'package:miserend/widgets/content_width.dart';
import 'package:miserend/widgets/list_status_view.dart';
import 'package:miserend/widgets/offline_notice.dart';

/// A church list read from the cache, with the banner above it once a
/// refresh has got no answer, and pull-to-refresh on the list or on its
/// empty message alike.
class ChurchListView extends StatelessWidget {
  const ChurchListView({
    super.key,
    required this.list,
    required this.emptyMessage,
    required this.onRefresh,
    this.position,
  });

  final ChurchList list;
  final String emptyMessage;
  final Future<void> Function() onRefresh;

  /// The position the rows show their distance from; null where the screen
  /// does not ask for one (spec 0007, „Hol jelenik meg a távolság").
  final LatLng? position;

  @override
  Widget build(BuildContext context) {
    final failure = list.failure;
    return Column(
      children: [
        if (failure != null)
          OfflineBanner(
            failure: failure,
            asOf: list.dataAsOf,
            onRetry: onRefresh,
          ),
        Expanded(
          child: RefreshIndicator.adaptive(
            onRefresh: onRefresh,
            child:
                list.churches.isEmpty
                    ? PullableFill(child: MessageView(message: emptyMessage))
                    : ContentColumns(
                      // The cards' own margin keeps them 8 apart (TK2).
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.l,
                        vertical: Spacing.xs,
                      ),
                      gap: CardRow.listGap,
                      builder: _grid,
                    ),
          ),
        ),
      ],
    );
  }

  /// The churches [columns] to a row, in their order (DESIGN.md EL3).
  Widget _grid(BuildContext context, EdgeInsets padding, int columns) {
    final churches = list.churches;
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      itemCount: (churches.length / columns).ceil(),
      itemBuilder: (BuildContext context, int row) {
        final first = row * columns;
        final cards = [
          for (final entry in churches.sublist(
            first,
            min(first + columns, churches.length),
          ))
            ChurchCard(entry: entry, position: position),
        ];
        return CardRow.of(columns, cards);
      },
    );
  }
}
