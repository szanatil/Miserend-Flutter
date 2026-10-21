import 'package:flutter/material.dart';

/// The strip under the search bar, the same on every tab, so that the tabs
/// read as one app: the Templomok tab puts its Közeli / Kedvencek tabs
/// on it, the others their name.
class SectionBar extends StatelessWidget implements PreferredSizeWidget {
  /// Tabs driven by the [DefaultTabController] above.
  const SectionBar.tabs(List<Tab> this.tabs, {super.key})
    : title = null,
      onBack = null;

  const SectionBar.title(String this.title, {super.key, this.onBack})
    : tabs = null;

  final List<Tab>? tabs;
  final String? title;

  /// Puts a back arrow before the title, for what opens in a tab's place
  /// rather than as a page of its own (spec 0010, „Keret").
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tabs = this.tabs;
    // Flat on the surface, like the title bar above it (DESIGN.md KO2, MÉ2).
    return SizedBox(
      height: kToolbarHeight,
      child: Material(
        color: theme.colorScheme.surface,
        child:
            tabs != null
                ? TabBar(tabs: tabs)
                : Stack(
                  children: [
                    Center(
                      child: Text(
                        title!,
                        style: theme.textTheme.titleMedium!.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (onBack != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: BackButton(onPressed: onBack),
                      ),
                  ],
                ),
      ),
    );
  }
}
