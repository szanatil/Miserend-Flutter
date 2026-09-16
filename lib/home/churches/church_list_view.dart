import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:miserend/home/churches/church_card.dart';
import 'package:miserend/home/churches/church_list_loader.dart';
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
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child:
                list.churches.isEmpty
                    ? PullableFill(child: MessageView(message: emptyMessage))
                    : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(8),
                      itemCount: list.churches.length,
                      itemBuilder:
                          (BuildContext context, int index) => ChurchCard(
                            entry: list.churches[index],
                            position: position,
                          ),
                    ),
          ),
        ),
      ],
    );
  }
}
