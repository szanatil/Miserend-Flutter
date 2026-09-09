import 'package:flutter/material.dart';

/// Church photos are served at up to 1200x900, which costs about 4.3MB of
/// memory once decoded. Drawn into a list thumbnail that is a waste of decode
/// time on every scroll, and it fills Flutter's 100MB image cache after
/// roughly twenty photos, so scrolling back re-downloads and re-decodes them.
/// Passing a decode height keeps each photo at the size it is actually drawn.
class PhotoDecode {
  /// Extra resolution so [BoxFit.cover] still has pixels to crop from when the
  /// photo is narrower than its slot. Covers sources down to a 2:3 portrait,
  /// which is past anything in the church photo set.
  static const double _coverHeadroom = 1.5;

  /// Decode height in device pixels for a slot [slotHeight] logical pixels
  /// tall. Pass [tight] for a slot taller than it is wide, where the height is
  /// already the axis cover scales by and no headroom is needed.
  static int forSlot(BuildContext context, double slotHeight,
      {bool tight = false}) {
    final double scale = tight ? 1 : _coverHeadroom;
    return (slotHeight * scale * MediaQuery.devicePixelRatioOf(context))
        .round();
  }
}
