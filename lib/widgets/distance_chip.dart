import 'package:flutter/material.dart';
import 'package:miserend/straight_line_distance.dart';

/// The straight-line distance to a church (CONTEXT.md, „Légvonal-távolság"),
/// the same on the church card and on the nearest masses' row. A dark,
/// see-through pill: it reads as grey on a white row and still stands out on
/// a photo, which may be as light as anything.
class DistanceChip extends StatelessWidget {
  const DistanceChip({super.key, required this.km});

  final double km;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const ShapeDecoration(
        color: Color.fromARGB(150, 0, 0, 0),
        shape: StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          formatDistance(km),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.apply(color: Colors.white),
        ),
      ),
    );
  }
}
