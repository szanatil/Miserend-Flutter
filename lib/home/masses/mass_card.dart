import 'package:flutter/material.dart';
import 'package:miserend/api/nearby_masses_item.dart';
import 'package:miserend/extentions.dart';
import 'package:miserend/home/masses/nearest_masses.dart';
import 'package:miserend/mass_detail.dart';
import 'package:miserend/theme/tokens.dart';
import 'package:miserend/widgets/distance_chip.dart';
import 'package:miserend/widgets/photo_decode.dart';
import 'package:miserend/widgets/photo_fade_in.dart';
import 'package:miserend/widgets/reserved_room.dart';
import 'package:miserend/widgets/tap_tooltip.dart';

/// One of the nearest masses, the church card's sibling: the same card and
/// distance chip (spec 0008). The start is not on it: the list
/// puts the masses starting together under one header that says when. Tapping
/// it opens the details page.
///
/// Short texts leave every card the same height: each line reserves its
/// room, as on the church card, the bubbles of the mass detail among them, so
/// that a detail arriving after the list does not push the cards below it
/// down. The room is reserved in the text size the lines are drawn in, and a
/// line too long for it wraps, so a larger text size or a long city makes the
/// card taller rather than overflow it (DESIGN.md EL2).
///
/// The screen reader reads it as one unit, the start first, though the card
/// does not show it: one card is read at a time, without its header
/// (DESIGN.md AM5).
///
/// Masses one church starts together share a card, the group mass card
/// (CONTEXT.md, „Csoportos misekártya"): the church once, and a row per mass,
/// its title first — Szentmise too, as it is what tells the rows apart — and
/// its detail's bubbles after it.
class MassCard extends StatelessWidget {
  MassCard({
    super.key,
    required NearbyMassesItem mass,
    String? detail,
    required this.thumbnailUrl,
    this.onTap,
  }) : masses = [mass],
       details = [detail];

  MassCard.group({
    super.key,
    required MassGroup group,
    required this.details,
    required this.thumbnailUrl,
    this.onTap,
  }) : assert(details.length == group.masses.length),
       masses = group.masses;

  /// Wide enough for the photo to help recognize the church.
  static const double photoWidth = 96;

  static const String _placeholder = 'assets/images/church_blurred.png';

  /// The one title not worth repeating on every card.
  static const String _plainMassTitle = 'Szentmise';

  /// Lines the name may take; the full name is on the details page.
  static const int _nameLines = 2;

  /// One church's masses at one start, in the list's order.
  final List<NearbyMassesItem> masses;

  /// Each mass's detail (CONTEXT.md, „Mise jellemzője"), once it has arrived:
  /// the list is drawn without it rather than wait (spec 0011). Each of its
  /// parts is drawn as a bubble of its own.
  final List<String?> details;

  /// The church and the start, which every mass on the card shares.
  NearbyMassesItem get _first => masses.first;

  /// The church's cached photo. The card is drawn with the placeholder until
  /// this resolves, so a slow cache never holds the list back.
  final Future<String?> thumbnailUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        label: TimeOfDay.fromDateTime(_first.start).to24hours(),
        child: _card(context),
      ),
    );
  }

  Widget _card(BuildContext context) {
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
                    padding: const EdgeInsets.all(Spacing.l),
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
                    right: Spacing.s,
                    bottom: Spacing.s,
                    child: DistanceChip(km: _first.distanceKm),
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
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    // As large as on the church card, its sibling (TI2).
    final nameStyle = textTheme.titleMedium;
    final lineStyle = textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final alone = masses.length == 1;
    final title = _first.title;
    final place = [
      _first.city,
      if (alone && title != _plainMassTitle) title,
    ].whereType<String>().join(' · ');

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
            _first.churchName ?? '?',
            style: nameStyle,
            maxLines: _nameLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // A long line wraps rather than being cut off (DESIGN.md EL2). An
        // empty text still takes its line.
        Text(place, style: lineStyle),
        if (alone) ...[
          const SizedBox(height: Spacing.s),
          _MassDetailBubbles(parts: _partsOf(details.single)),
        ] else
          for (final (index, mass) in masses.indexed) ...[
            const SizedBox(height: Spacing.s),
            _MassDetailBubbles(
              title: Text(mass.title ?? '?', style: lineStyle),
              parts: _partsOf(details[index]),
            ),
          ],
      ],
    );
  }

  static List<MassDetailPart> _partsOf(String? detail) =>
      detail == null ? const <MassDetailPart>[] : massDetailParts(detail);

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
          excludeFromSemantics: true,
        );

        return FutureBuilder<String?>(
          future: thumbnailUrl,
          builder: (context, snapshot) {
            final url = snapshot.data;
            if (url == null) return placeholder;
            return PhotoFadeIn(
              image: url,
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
/// they need, after the mass's [title] on a group mass card. One line is
/// reserved on every card, and on every row of a group mass card, so that a
/// detail arriving after the list, one line long as most are, does not push
/// the cards below it down.
class _MassDetailBubbles extends StatelessWidget {
  const _MassDetailBubbles({this.title, required this.parts});

  final Widget? title;
  final List<MassDetailPart> parts;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return ReservedRoom(
      placeholder: const _BubbleSurface(part: MassDetailText('')),
      child: Wrap(
        spacing: Spacing.s,
        runSpacing: Spacing.s,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (title != null) title,
          for (final part in parts) MassDetailBubble(part: part),
        ],
      ),
    );
  }
}

/// One part of the mass detail (CONTEXT.md, „Mise jellemzője"): a type as its
/// icon and its word, a language or a comment as written. A comment too long
/// for the card is cut off with an ellipsis; tapped, that bubble shows its
/// whole text above it until another touch or a scroll, for at most 10 s, and
/// does not open the church. A
/// bubble shown in full is the card's: tapping it opens the church (DESIGN.md
/// KO21, spec 0011).
class MassDetailBubble extends StatelessWidget {
  const MassDetailBubble({super.key, required this.part});

  final MassDetailPart part;

  @override
  Widget build(BuildContext context) {
    // Whether the text is cut off is asked again on every layout, as the
    // width, the text size and the screen's turn all change it.
    return LayoutBuilder(
      builder: (context, constraints) {
        final surface = _BubbleSurface(part: part);
        if (!constraints.hasBoundedWidth ||
            !surface.cutsOffIn(context, constraints.maxWidth)) {
          return surface;
        }
        // No ripple or highlight: the ellipsis tells it is tappable (KO4).
        return TapTooltip(message: part.label, child: surface);
      },
    );
  }
}

/// The surface of a [MassDetailBubble], a data chip in the mass detail's
/// colours (DESIGN.md KO4, SZ4), also laid out empty to reserve the bubbles'
/// line on a card without them.
class _BubbleSurface extends StatelessWidget {
  const _BubbleSurface({required this.part});

  final MassDetailPart part;

  /// A chip's icon size (IK3).
  static const double _iconSize = IconSizes.small;

  /// The bubble's inner padding, either side of its content.
  static const EdgeInsets _padding = EdgeInsets.symmetric(
    horizontal: Spacing.s,
    vertical: Spacing.xs,
  );

  TextStyle? _labelStyle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.labelLarge?.copyWith(
      color: theme.colorScheme.onSecondaryContainer,
    );
  }

  /// Whether the label, on one line, is cut off in a bubble [maxWidth] wide.
  /// It is measured as [Text] draws it, bold when the phone asks for bold
  /// text.
  bool cutsOffIn(BuildContext context, double maxWidth) {
    final iconRoom = part.iconAsset == null ? 0 : _iconSize + Spacing.s;
    var style = DefaultTextStyle.of(context).style.merge(_labelStyle(context));
    if (MediaQuery.boldTextOf(context)) {
      style = style.merge(const TextStyle(fontWeight: FontWeight.bold));
    }
    final painter = TextPainter(
      text: TextSpan(text: part.label, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width > maxWidth - _padding.horizontal - iconRoom;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconAsset = part.iconAsset;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: scheme.secondaryContainer,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(Radii.s)),
        ),
      ),
      child: Padding(
        padding: _padding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconAsset != null) ...[
              Image.asset(
                iconAsset,
                width: _iconSize,
                height: _iconSize,
                color: scheme.onSecondaryContainer,
                excludeFromSemantics: true,
              ),
              const SizedBox(width: Spacing.s),
            ],
            Flexible(
              child: Text(
                part.label,
                style: _labelStyle(context),
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
