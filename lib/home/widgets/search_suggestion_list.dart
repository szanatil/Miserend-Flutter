import 'package:flutter/material.dart';

/// The suggestions under the search bar. It stands in for [SearchAnchor]'s
/// own list, which pads its end by the keyboard's height: that suits a
/// full-screen view reaching under the keyboard, but the home screen's view
/// is capped above it, so scrolled to the end the last suggestion ran off
/// and an empty keyboard-high space was left in its place.
class SearchSuggestionList extends StatelessWidget {
  const SearchSuggestionList({super.key, required this.suggestions});

  final Iterable<Widget> suggestions;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      removeBottom: true,
      child: ListView(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        children: suggestions.toList(),
      ),
    );
  }
}
