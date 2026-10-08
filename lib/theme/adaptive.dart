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
