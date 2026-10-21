import 'package:flutter/material.dart';
import 'package:miserend/home/churches/church_list_loader.dart';
import 'package:miserend/home/churches/favorite_churches.dart';
import 'package:miserend/home/churches/near_churches_page.dart';
import 'package:miserend/home/widgets/section_bar.dart';
import 'package:miserend/home/widgets/tab_reselect.dart';
import 'package:miserend/location_provider.dart';

const List<Tab> tabs = <Tab>[Tab(text: 'Közeli'), Tab(text: 'Kedvencek')];

class ChurchesPage extends StatelessWidget {
  const ChurchesPage({
    super.key,
    this.nearLoader,
    this.favoritesLoader,
    this.location,
  });

  /// Injected by tests; the Közeli tab builds its own otherwise.
  final ChurchListLoader? nearLoader;

  /// Injected by tests; the Kedvencek tab builds its own otherwise.
  final ChurchListLoader? favoritesLoader;

  /// Injected by tests; the Közeli tab builds its own otherwise.
  final LocationProvider? location;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: tabs.length,
      child: _BackToFirstTab(
        child: Scaffold(
          appBar: const SectionBar.tabs(tabs),
          body: TabBarView(
            children: [
              NearChurchesPage(loader: nearLoader, location: location),
              FavoriteChurchesPage(loader: favoritesLoader),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Templomok tab tapped again on its root goes back to the Közeli tab
/// first, and only from there to the top of the list (DESIGN.md NA4).
class _BackToFirstTab extends StatefulWidget {
  const _BackToFirstTab({required this.child});

  final Widget child;

  @override
  State<_BackToFirstTab> createState() => _BackToFirstTabState();
}

class _BackToFirstTabState extends State<_BackToFirstTab> {
  TabReselectHandlers? _handlers;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final handlers = TabReselect.maybeOf(context);
    if (handlers == _handlers) return;
    _handlers?.remove(_toFirstTab);
    _handlers = handlers?..add(_toFirstTab);
  }

  @override
  void dispose() {
    _handlers?.remove(_toFirstTab);
    super.dispose();
  }

  bool _toFirstTab() {
    final controller = DefaultTabController.of(context);
    if (controller.index == 0) return false;
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.index = 0;
    } else {
      controller.animateTo(
        0,
        duration: Durations.medium3,
        curve: Easing.standard,
      );
    }
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
