import 'package:flutter/material.dart';

/// The suggestions under the search bar. It stands in for [SearchAnchor]'s
/// own list, which pads its end by the keyboard's height: that suits a
/// full-screen view reaching under the keyboard, but the home screen's view
/// is capped above it, so scrolled to the end the last suggestion ran off
/// and an empty keyboard-high space was left in its place.
///
/// A [footer] stays put below the suggestions, which scroll above it, so that
/// however many there are it never runs out of sight (spec 0010, „Belépés").
class SearchSuggestionList extends StatelessWidget {
  const SearchSuggestionList({
    super.key,
    required this.suggestions,
    this.footer,
  });

  final Iterable<Widget> suggestions;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final footer = this.footer;
    final children = suggestions.toList();
    final list = ListView(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      children: children,
    );
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      removeBottom: true,
      child:
          footer == null
              ? list
              : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: list),
                  // With no suggestions, the view's own divider is above.
                  if (children.isNotEmpty) const Divider(height: 1),
                  footer,
                ],
              ),
    );
  }
}
