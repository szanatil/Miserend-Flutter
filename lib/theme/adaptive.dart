/// The one place where Android and iOS part ways (DESIGN.md PL3): helpers
/// such as `showMiserendDialog` that pick the platform's own element from
/// `Theme.of(context).platform`, so that no screen branches by platform.
///
/// The rest of the adaptive elements of PL2 arrive with #60.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Opens a task flow such as the Hibajelentés (DESIGN.md NA2): a modal sheet
/// on iOS, a full-screen dialog on Android. Either covers the navigation bar,
/// so it goes on the root navigator rather than the tab's own (NA1).
Future<T?> pushMiserendTaskFlow<T>(
  BuildContext context,
  WidgetBuilder builder,
) {
  final PageRoute<T> route = switch (Theme.of(context).platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => CupertinoSheetRoute<T>(
      // The sheet hands over its controller so that the page's list drags
      // the sheet down once scrolled to the top.
      scrollableBuilder:
          (context, controller) => PrimaryScrollController(
            controller: controller,
            child: builder(context),
          ),
    ),
    _ => MaterialPageRoute<T>(builder: builder, fullscreenDialog: true),
  };
  return Navigator.of(context, rootNavigator: true).push(route);
}

/// A tab of [MiserendNavigationBar]: the outlined [icon] (DESIGN.md IK2),
/// filled as [selectedIcon] while the tab is on screen. An icon with no
/// rounded outline has no [selectedIcon] and stays as it is.
class MiserendDestination {
  const MiserendDestination({
    required this.icon,
    this.selectedIcon,
    required this.label,
  });

  final Widget icon;
  final Widget? selectedIcon;
  final String label;
}

/// The bottom navigation (DESIGN.md KO16): the M3 [NavigationBar] in its own
/// colours on Android, a [CupertinoTabBar] on iOS. The labels always show
/// (NA6).
class MiserendNavigationBar extends StatelessWidget {
  const MiserendNavigationBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<MiserendDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  /// Where the M3 [NavigationBar] stops growing its labels.
  static const double _maxLabelTextScale = 1.3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return switch (theme.platform) {
      // The labels grow with the text up to the M3 bar's own limit: at 2.0,
      // a quarter of a 320 dp screen broke „Templomok" in two, and the bar's
      // fixed height overflowed.
      TargetPlatform.iOS ||
      TargetPlatform.macOS => MediaQuery.withClampedTextScaling(
        maxScaleFactor: _maxLabelTextScale,
        child: CupertinoTabBar(
          items: [
            for (final destination in destinations)
              BottomNavigationBarItem(
                icon: destination.icon,
                activeIcon: destination.selectedIcon,
                label: destination.label,
              ),
          ],
          currentIndex: selectedIndex,
          onTap: onDestinationSelected,
          activeColor: theme.colorScheme.primary,
          inactiveColor: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      _ => NavigationBar(
        destinations: [
          for (final destination in destinations)
            NavigationDestination(
              icon: destination.icon,
              selectedIcon: destination.selectedIcon,
              label: destination.label,
            ),
        ],
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    };
  }
}
