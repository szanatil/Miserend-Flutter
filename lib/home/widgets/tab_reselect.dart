import 'package:flutter/widgets.dart';

/// Hands the tap on the tab on screen (DESIGN.md NA4) to the tab's page
/// before the screen scrolls its list to the top: a page with tabs of its own
/// first goes back to the first of them.
class TabReselect extends InheritedWidget {
  const TabReselect({super.key, required this.handlers, required super.child});

  final TabReselectHandlers handlers;

  /// Null outside a tab.
  static TabReselectHandlers? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<TabReselect>()?.handlers;

  @override
  bool updateShouldNotify(TabReselect oldWidget) =>
      handlers != oldWidget.handlers;
}

/// What a tab's pages do when the tab is tapped again on its root. Each
/// handler says whether it took the tap.
class TabReselectHandlers {
  final List<bool Function()> _handlers = [];

  void add(bool Function() handler) => _handlers.add(handler);

  void remove(bool Function() handler) => _handlers.remove(handler);

  /// Whether one of the pages took the tap; the first that does ends it.
  bool handle() => _handlers.any((handler) => handler());
}
