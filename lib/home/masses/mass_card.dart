import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:miserend/api/nearby_masses_item.dart';
import 'package:miserend/colors.dart';
import 'package:miserend/extentions.dart';
import 'package:miserend/home/masses/nearest_masses.dart';
import 'package:miserend/widgets/distance_chip.dart';
import 'package:miserend/widgets/photo_decode.dart';
import 'package:miserend/widgets/reserved_room.dart';

/// One of the nearest masses, the church card's sibling: the same card, grey
/// ground and distance chip, but built around the start, because on this tab
/// *when* decides (spec 0008). Tapping it opens the details page.
///
/// Every card is the same height whatever it says: each line reserves its
/// room, as on the church card, so the starts run down the list in one
/// column. The room is reserved in the text size the lines are drawn in,
/// so a larger text size makes the card taller rather than overflow it.
class MassCard extends StatelessWidget {
  const MassCard({
    super.key,
    required this.mass,
    required this.now,
    required this.thumbnailUrl,
    this.onTap,
  });

  /// Wide enough for the photo to help recognize the church, narrow enough
  /// to leave the start the lead.
  static const double photoWidth = 96;

  static const String _placeholder = 'assets/images/church_blurred.png';

  /// The one title not worth repeating on every card.
  static const String _plainMassTitle = 'Szentmise';

  /// Lines the name may take; the full name is on the details page.
  static const int _nameLines = 2;

  /// The widest start and the widest text under it, which size the time
  /// column so that the church column starts at the same place on every card.
  static const String _widestStart = '00:00';

  /// Follows [timeUntilStartLimit]: the longest text below two hours.
  static const String _widestTimeUntil = '1 óra 59 perc múlva';

  /// The most of the card's width the time column may take. Only a large text
  /// size reaches it; the name keeps the rest.
  static const double _timeColumnMaxShare = 0.3;

  final NearbyMassesItem mass;

  /// The moment the list was selected at, for the time until start and the
  /// ongoing mark.
  final DateTime now;

  /// The church's cached photo. The card is drawn with the placeholder until
  /// this resolves, so a slow cache never holds the list back.
  final Future<String?> thumbnailUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            LayoutBuilder(
              builder:
                  (context, constraints) => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        child: _timeColumn(context, constraints.maxWidth),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                          child: _churchColumn(context),
                        ),
                      ),
                      const SizedBox(width: photoWidth),
                    ],
                  ),
            ),
            // Laid over the reserved strip rather than in the row, so that the
            // photo takes the card's height instead of setting it.
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              width: photoWidth,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _photo(),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: DistanceChip(km: mass.distanceKm),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeColumn(BuildContext context, double cardWidth) {
    final textTheme = Theme.of(context).textTheme;
    final startStyle = textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.bold,
      color: CustomColors.accent,
    );
    final untilStyle = textTheme.bodySmall?.apply(color: Colors.grey);
    // The two exclude each other: an ongoing mass has no time until start.
    final ongoing = isOngoing(mass, now);
    final until = ongoing ? null : timeUntilStart(mass.start, now);

    final textScaler = MediaQuery.textScalerOf(context);
    double widthOf(String text, TextStyle? style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    // Measured rather than reserved with invisible text, which would stand in
    // the tree as text nobody sees.
    final widest = [
      widthOf(_widestStart, startStyle),
      widthOf(_widestTimeUntil, untilStyle),
      widthOf(_OngoingBadge.label, _OngoingBadge.style(context)) +
          2 * _OngoingBadge.horizontalPadding,
    ].reduce(math.max);
    final width = math.min(
      widest.ceilToDouble(),
      cardWidth * _timeColumnMaxShare,
    );

    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shrinks rather than cuts off once a large text size leaves it
          // too little room: the start is the one thing to read.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              TimeOfDay.fromDateTime(mass.start).to24hours(),
              style: startStyle,
            ),
          ),
          ReservedRoom(
            // The badge's own height, with no text of its own to find.
            placeholder: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: _OngoingBadge.verticalPadding,
              ),
              child: Text('', style: _OngoingBadge.style(context)),
            ),
            // One line either way, shrunk like the start rather than wrapped,
            // which would make this card taller than the others.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child:
                  ongoing
                      ? const _OngoingBadge()
                      : Text(until ?? '', style: untilStyle),
            ),
          ),
        ],
      ),
    );
  }

  Widget _churchColumn(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final nameStyle = textTheme.titleMedium;
    final title = mass.title;
    final place = [
      mass.city,
      if (title != _plainMassTitle) title,
    ].whereType<String>().join(' · ');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Both lines stay reserved for a short name, so that the line under it
        // stands at the same height on every card.
        ReservedRoom.lines(
          lines: _nameLines,
          style: nameStyle,
          child: Text(
            mass.churchName ?? '?',
            style: nameStyle,
            maxLines: _nameLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // One line for both: a title is rare, and a line of its own would be
        // empty on almost every card. A long city cuts the title off.
        // An empty text still takes its line.
        Text(
          place,
          style: textTheme.bodyMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _photo() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Church photos are landscape, wider for their height than the strip,
        // so height is the axis [BoxFit.cover] scales by and needs no headroom.
        final int decodeHeight = PhotoDecode.forSlot(
          context,
          constraints.maxHeight,
          tight: true,
        );
        final placeholder = Image.asset(
          _placeholder,
          fit: BoxFit.cover,
          cacheHeight: decodeHeight,
        );

        return FutureBuilder<String?>(
          future: thumbnailUrl,
          builder: (context, snapshot) {
            final url = snapshot.data;
            if (url == null) return placeholder;
            return FadeInImage.assetNetwork(
              image: url,
              fit: BoxFit.cover,
              placeholder: _placeholder,
              imageErrorBuilder: (context, error, stackTrace) => placeholder,
              imageCacheHeight: decodeHeight,
              placeholderCacheHeight: decodeHeight,
            );
          },
        );
      },
    );
  }
}

/// Marks an ongoing mass in place of its time until start (CONTEXT.md,
/// „Épp most tartó mise").
class _OngoingBadge extends StatelessWidget {
  const _OngoingBadge();

  static const String label = 'Épp most tart';
  static const double horizontalPadding = 8;
  static const double verticalPadding = 2;

  static TextStyle? style(BuildContext context) => Theme.of(context)
      .textTheme
      .labelMedium
      ?.copyWith(color: Theme.of(context).colorScheme.onPrimaryContainer);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: style(context)),
    );
  }
}
