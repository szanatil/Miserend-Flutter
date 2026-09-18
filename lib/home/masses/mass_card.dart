import 'package:flutter/material.dart';
import 'package:miserend/api/nearby_masses_item.dart';
import 'package:miserend/colors.dart';
import 'package:miserend/mass_detail.dart';
import 'package:miserend/widgets/distance_chip.dart';
import 'package:miserend/widgets/photo_decode.dart';
import 'package:miserend/widgets/reserved_room.dart';

/// One of the nearest masses, the church card's sibling: the same card, grey
/// ground and distance chip (spec 0008). The start is not on it: the list
/// puts the masses starting together under one header that says when. Tapping
/// it opens the details page.
///
/// Every card is the same height whatever it says: each line reserves its
/// room, as on the church card, the bubbles of the mass detail among them, so
/// that a detail arriving after the list does not push the cards below it
/// down. The room is reserved in the text size the lines are drawn in, so a
/// larger text size makes the card taller rather than overflow it.
class MassCard extends StatelessWidget {
  const MassCard({
    super.key,
    required this.mass,
    this.detail,
    required this.thumbnailUrl,
    this.onTap,
  });

  /// Wide enough for the photo to help recognize the church.
  static const double photoWidth = 96;

  static const String _placeholder = 'assets/images/church_blurred.png';

  /// The one title not worth repeating on every card.
  static const String _plainMassTitle = 'Szentmise';

  /// Lines the name may take; the full name is on the details page.
  static const int _nameLines = 2;

  final NearbyMassesItem mass;

  /// The mass detail (CONTEXT.md, „Mise jellemzője"), once it has arrived:
  /// the list is drawn without it rather than wait (spec 0011). Each of its
  /// parts is drawn as a bubble of its own.
  final String? detail;

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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                    child: _churchColumn(context),
                  ),
                ),
                const SizedBox(width: photoWidth),
              ],
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

  Widget _churchColumn(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final nameStyle = textTheme.titleMedium;
    final title = mass.title;
    final place = [
      mass.city,
      if (title != _plainMassTitle) title,
    ].whereType<String>().join(' · ');
    final detail = this.detail;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Both lines stay reserved for a short name, so that the lines under
        // it stand at the same height on every card.
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
        // The city leads, so a long one cuts the title off. An empty text
        // still takes its line.
        Text(
          place,
          style: textTheme.bodyMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: _MassDetailBubbles.gap),
        _MassDetailBubbles(
          parts:
              detail == null
                  ? const <MassDetailPart>[]
                  : massDetailParts(detail),
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

/// The mass detail's bubbles, one per part, wrapping onto as many lines as
/// they need. One line is reserved on every card, so that a detail arriving
/// after the list, one line long as most are, does not push the cards below
/// it down.
class _MassDetailBubbles extends StatelessWidget {
  const _MassDetailBubbles({required this.parts});

  final List<MassDetailPart> parts;

  /// Between two bubbles, and between the city line and the bubbles.
  static const double gap = 6;

  @override
  Widget build(BuildContext context) {
    return ReservedRoom(
      placeholder: const _BubbleSurface(part: MassDetailText('')),
      child: Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final part in parts) MassDetailBubble(part: part)],
      ),
    );
  }
}

/// One part of the mass detail (CONTEXT.md, „Mise jellemzője"): a type as its
/// icon and its word, a language or a comment as written. A comment too long
/// for the card is cut off with an ellipsis; tapped, the bubble shows its
/// whole text above it, and does not open the church.
class MassDetailBubble extends StatelessWidget {
  const MassDetailBubble({super.key, required this.part});

  final MassDetailPart part;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: part.label,
      triggerMode: TooltipTriggerMode.tap,
      preferBelow: false,
      // The bubble's text reads the same.
      excludeFromSemantics: true,
      child: _BubbleSurface(part: part),
    );
  }
}

/// The yellow surface of a [MassDetailBubble], also laid out empty to reserve
/// the bubbles' line on a card without them.
class _BubbleSurface extends StatelessWidget {
  const _BubbleSurface({required this.part});

  final MassDetailPart part;

  static const double _horizontalPadding = 8;
  static const double _verticalPadding = 2;
  static const double _iconGap = 4;

  static TextStyle? _style(BuildContext context) =>
      Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.black87);

  /// As tall as the letters, in the text size they are drawn in.
  static double _iconSize(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(_style(context)?.fontSize ?? 12);

  @override
  Widget build(BuildContext context) {
    final iconAsset = part.iconAsset;
    final iconSize = _iconSize(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CustomColors.massDetailTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _horizontalPadding,
          vertical: _verticalPadding,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconAsset != null) ...[
              Image.asset(
                iconAsset,
                width: iconSize,
                height: iconSize,
                color: Colors.black87,
                excludeFromSemantics: true,
              ),
              const SizedBox(width: _iconGap),
            ],
            Flexible(
              child: Text(
                part.label,
                style: _style(context),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
