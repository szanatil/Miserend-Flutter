import 'package:flutter/material.dart';

/// The purple strip under the search bar, the same on every tab, so that the
/// tabs read as one app: the Templomok tab puts its Közeli / Kedvencek tabs
/// on it, the others their name.
class SectionBar extends StatelessWidget implements PreferredSizeWidget {
  /// Tabs driven by the [DefaultTabController] above.
  const SectionBar.tabs(List<Tab> this.tabs, {super.key}) : title = null;

  const SectionBar.title(String this.title, {super.key}) : tabs = null;

  final List<Tab>? tabs;
  final String? title;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final tabs = this.tabs;
    return SizedBox(
      height: kToolbarHeight,
      child: Material(
        elevation: 4,
        color: Theme.of(context).primaryColor,
        child:
            tabs != null
                ? TabBar(
                  tabs: tabs,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  indicatorColor: Colors.white,
                )
                : Center(
                  child: Text(
                    title!,
                    // The tab labels' style, so that a title reads like them.
                    style: (TabBarTheme.of(context).labelStyle ??
                            Theme.of(context).textTheme.titleSmall)
                        ?.copyWith(color: Colors.white),
                  ),
                ),
      ),
    );
  }
}
