import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:latlong2/latlong.dart';
import 'package:miserend/api/api_result.dart';
import 'package:miserend/church_details/church_details_page.dart';
import 'package:miserend/church_details/church_schedule_loader.dart';
import 'package:miserend/database/cache/cached_mass.dart';
import 'package:miserend/database/cache/church_list_entry.dart';
import 'package:miserend/database/church.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/extentions.dart';
import 'package:miserend/home/masses/nearest_masses.dart';
import 'package:miserend/mass_kind.dart';
import 'package:miserend/straight_line_distance.dart';
import 'package:miserend/theme/tokens.dart';
import 'package:miserend/widgets/distance_chip.dart';
import 'package:miserend/widgets/offline_notice.dart';
import 'package:miserend/widgets/photo_decode.dart';
import 'package:miserend/widgets/photo_fade_in.dart';
import 'package:miserend/widgets/reserved_room.dart';
import 'package:miserend/widgets/time_chip.dart';
import 'package:provider/provider.dart';

/// One church of a list read from the cache: its names, today's masses, its
/// first photo and, where the screen knows the position, how far it is.
/// Tapping it opens the details page.
class ChurchCard extends StatelessWidget {
  const ChurchCard({
    super.key,
    required this.entry,
    this.position,
    this.failure,
    this.dataAsOf,
    this.clock = DateTime.now,
  });

  final ChurchListEntry entry;

  /// The user's position, for the straight-line distance on the photo. Null
  /// where the screen has none or does not ask for one — favorites and search
  /// do not (spec 0007, „Hol jelenik meg a távolság").
  final LatLng? position;

  /// Set where the card stands alone — the map's — and its own refresh got no
  /// answer; a list marks itself once, above the rows, instead.
  final ApiFailure? failure;

  /// How old the church's data is, for the (i) explanation.
  final DateTime? dataAsOf;

  /// The time now, for marking the masses going on. Injected by tests.
  final DateTime Function() clock;

  /// Lines the name may take; a third would take the common name's place, and
  /// the full name is on the details page.
  static const int _nameLines = 2;

  /// The text takes two thirds of the card, the photo the third beside it.
  static const int _textFlex = 2;
  static const int _photoFlex = 1;

  @override
  Widget build(BuildContext context) {
    // Confession, adoration and the hours come back among the rows too; the
    // chips promise a mass (CONTEXT.md, „Napi miserend").
    final masses = entry.masses.where(isMass).toList();
    final km = straightLineKm(position, entry.lat, entry.lon);
    final failure = this.failure;
    final favoritesService = context.watch<FavoritesService>();
    final favorite = favoritesService.isFavorite(entry.id);
    void toggleFavorite() => favoritesService.toggle(entry.id);

    // Read out as one unit, today's masses first (DESIGN.md AM5). The
    // buttons on it, merged into it, would lose their own tap: they are the
    // card's actions instead.
    return MergeSemantics(
      child: Semantics(
        label:
            masses.isEmpty
                ? null
                : masses
                    .map(
                      (mass) => TimeOfDay.fromDateTime(mass.time).to24hours(),
                    )
                    .join(', '),
        customSemanticsActions: {
          CustomSemanticsAction(label: _favoriteLabel(favorite)):
              toggleFavorite,
          if (failure != null)
            const CustomSemanticsAction(label: OfflineInfoButton.tooltip):
                () => OfflineNotice.show(context, failure, dataAsOf),
        },
        // A row of cards gives each the height of the tallest (DESIGN.md
        // EL3); elsewhere the card is as tall as its content (EL2).
        child: LayoutBuilder(
          builder:
              (context, constraints) => _card(
                context,
                masses,
                km,
                favorite,
                toggleFavorite,
                stretched: constraints.hasTightHeight,
              ),
        ),
      ),
    );
  }

  Widget _card(
    BuildContext context,
    List<CachedMass> masses,
    double? km,
    bool favorite,
    VoidCallback toggleFavorite, {
    required bool stretched,
  }) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final scheme = theme.colorScheme;
    final failure = this.failure;

    return Card(
      color: failure?.cardTint(context),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openChurchDetails(context, entry),
        // The text sets the card's height; the photo is laid over the
        // third left free for it, so that it takes that height instead of
        // setting it (DESIGN.md EL2). Stretched, the room left over goes
        // under the common name, so that the chips, the line and the heart
        // stand level across the row.
        child: Stack(
          fit: stretched ? StackFit.expand : StackFit.loose,
          children: [
            Row(
              crossAxisAlignment:
                  stretched
                      ? CrossAxisAlignment.stretch
                      : CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: _textFlex,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                Spacing.l,
                                Spacing.l,
                                Spacing.l,
                                0,
                              ),
                              // The slot keeps both lines even for a short
                              // name, so that everything below stands at
                              // the same height on every card.
                              child: ReservedRoom.lines(
                                lines: _nameLines,
                                style: textTheme.titleMedium,
                                child: Text(
                                  entry.name ?? '',
                                  style: textTheme.titleMedium,
                                  maxLines: _nameLines,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          if (failure != null)
                            ExcludeSemantics(
                              child: OfflineInfoButton(
                                failure: failure,
                                asOf: dataAsOf,
                              ),
                            ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Spacing.l,
                          Spacing.s,
                          Spacing.l,
                          Spacing.m,
                        ),
                        // An empty text still takes its line; a long one
                        // wraps (DESIGN.md EL2).
                        child: Text(
                          entry.commonName ?? '',
                          style: textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (stretched) const Spacer(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Spacing.l,
                          0,
                          Spacing.l,
                          Spacing.s,
                        ),
                        // Read out first, on the card's own label.
                        child: ExcludeSemantics(
                          child: _MassChips(masses: masses, now: clock()),
                        ),
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: scheme.outlineVariant,
                      ),
                      ExcludeSemantics(
                        child: IconButton(
                          icon:
                              favorite
                                  ? const Icon(Icons.favorite_rounded)
                                  : const Icon(Icons.favorite_border_rounded),
                          color:
                              favorite
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                          tooltip: _favoriteLabel(favorite),
                          onPressed: toggleFavorite,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: _photoFlex),
              ],
            ),
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: FractionallySizedBox(
                  widthFactor: _photoFlex / (_textFlex + _photoFlex),
                  heightFactor: 1,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _photo(),
                      // Over the photo rather than in the text column, so
                      // that a card without it has nothing moved.
                      if (km != null)
                        Positioned(
                          right: Spacing.s,
                          bottom: Spacing.s,
                          child: DistanceChip(km: km),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// What the heart does, on its tooltip and as the card's action.
  static String _favoriteLabel(bool favorite) =>
      favorite ? 'Törlés a kedvencek közül' : 'Kedvencekhez';

  /// The photo strip, as tall as the card.
  Widget _photo() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The strip is a third of the card wide and the full card tall, so
        // height is the axis [BoxFit.cover] scales by and needs no headroom.
        final decodeHeight = PhotoDecode.forSlot(
          context,
          constraints.maxHeight,
          tight: true,
        );
        final placeholder = Image.asset(
          'assets/images/church_blurred.png',
          fit: BoxFit.cover,
          cacheHeight: decodeHeight,
          excludeFromSemantics: true,
        );
        final photo = entry.photo;
        return photo != null && photo.isNotEmpty
            ? PhotoFadeIn(
              image: photo,
              placeholder: 'assets/images/church_blurred.png',
              imageErrorBuilder: (context, error, stackTrace) => placeholder,
              imageCacheHeight: decodeHeight,
              placeholderCacheHeight: decodeHeight,
            )
            : placeholder;
      },
    );
  }
}

/// Today's masses on a single line. Those that do not fit give way to one
/// [TimeChip.more]; how many fit depends on the card's actual width, which
/// differs from phone to phone.
class _MassChips extends StatelessWidget {
  const _MassChips({required this.masses, required this.now});

  final List<CachedMass> masses;

  /// For marking the masses going on (CONTEXT.md, „Épp most tartó mise").
  final DateTime now;

  static const double _spacing = Spacing.s;

  @override
  Widget build(BuildContext context) {
    final times = [
      for (final mass in masses) TimeOfDay.fromDateTime(mass.time),
    ];

    double chipWidth(String label) => TimeChip.widthOf(context, label);

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final widths = [for (final time in times) chipWidth(time.to24hours())];

        var fitting = times.length;
        final all = widths.fold(0.0, (sum, w) => sum + w + _spacing) - _spacing;
        if (times.isNotEmpty && all > available) {
          final room = available - chipWidth(TimeChip.moreLabel);
          var used = 0.0;
          fitting = 0;
          while (fitting < times.length &&
              used + widths[fitting] + _spacing <= room) {
            used += widths[fitting] + _spacing;
            fitting++;
          }
        }

        // A day without a mass keeps the line, so that the line and the heart
        // below stand where they do on every card (DESIGN.md EL2).
        return ConstrainedBox(
          constraints: BoxConstraints(minHeight: TimeChip.heightOf(context)),
          child: Row(
            children: [
              for (var i = 0; i < fitting; i++) ...[
                if (i > 0) const SizedBox(width: _spacing),
                TimeChip(
                  time: times[i],
                  ongoing: isOngoingStart(masses[i].time, now),
                ),
              ],
              if (fitting < times.length) ...[
                if (fitting > 0) const SizedBox(width: _spacing),
                const TimeChip.more(),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Opens the details page of [entry]. The page loads everything by id; the
/// entry only seeds the name, the map and the header until then. [loader] is
/// injected by tests; the page builds its own otherwise.
void openChurchDetails(
  BuildContext context,
  ChurchListEntry entry, {
  ChurchScheduleLoader? loader,
}) {
  final church = Church(
    id: entry.id,
    name: entry.name,
    commonName: entry.commonName,
    isGreek: null,
    lat: entry.lat,
    lon: entry.lon,
    address: null,
    city: entry.city,
    country: null,
    county: null,
    street: null,
    gettingThere: null,
    imageUrl: entry.photo,
  );
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ChurchDetailsPage(church: church, loader: loader),
    ),
  );
}
