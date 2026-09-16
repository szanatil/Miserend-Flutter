import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:miserend/api/api_result.dart';
import 'package:miserend/church_details/church_details_page.dart';
import 'package:miserend/colors.dart';
import 'package:miserend/database/cache/cached_mass.dart';
import 'package:miserend/database/cache/church_list_entry.dart';
import 'package:miserend/database/church.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/extentions.dart';
import 'package:miserend/mass_kind.dart';
import 'package:miserend/straight_line_distance.dart';
import 'package:miserend/widgets/distance_chip.dart';
import 'package:miserend/widgets/offline_notice.dart';
import 'package:miserend/widgets/photo_decode.dart';
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
  });

  /// The card's fixed height in logical pixels. Fixed, so that a list scrolls
  /// evenly and the map can keep its buttons clear of the card.
  static const double height = 192;

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

  /// Lines the name may take; a third would take the common name's place, and
  /// the full name is on the details page.
  static const int _nameLines = 2;

  @override
  Widget build(BuildContext context) {
    // Confession, adoration and the hours come back among the rows too; the
    // chips promise a mass (CONTEXT.md, „Napi miserend").
    final masses = entry.masses.where(isMass).toList();
    final km = straightLineKm(position, entry.lat, entry.lon);
    final textTheme = Theme.of(context).textTheme;

    final failure = this.failure;

    return Center(
      child: Card(
        color:
            failure == ApiFailure.serverError
                ? CustomColors.serverErrorTint
                : null,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          splashColor: Colors.blue.withAlpha(30),
          onTap: () => openChurchDetails(context, entry),
          child: SizedBox(
            height: height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                8.0,
                                8.0,
                                8.0,
                                4.0,
                              ),
                              // The slot keeps both lines even for a short
                              // name, so that everything below stands at the
                              // same height on every card.
                              child: _LineSlot(
                                lines: _nameLines,
                                style: textTheme.titleLarge,
                                child: Text(
                                  entry.name ?? '',
                                  style: textTheme.titleLarge,
                                  maxLines: _nameLines,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          if (failure != null)
                            OfflineInfoButton(failure: failure, asOf: dataAsOf),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8.0, 0.0, 8.0, 8.0),
                        // An empty text still takes its line.
                        child: Text(
                          entry.commonName ?? '',
                          style: textTheme.titleMedium?.apply(
                            color: Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: _MassChips(masses: masses),
                      ),
                      Container(color: Colors.grey, height: 1),
                      Consumer<FavoritesService>(
                        builder: (context, favoritesService, child) {
                          final favorite = favoritesService.isFavorite(
                            entry.id,
                          );
                          return IconButton(
                            icon:
                                favorite
                                    ? const Icon(Icons.favorite)
                                    : const Icon(Icons.favorite_border),
                            color: Colors.grey,
                            tooltip:
                                favorite
                                    ? 'Törlés a kedvencek közül'
                                    : 'Kedvencekhez',
                            onPressed: () => favoritesService.toggle(entry.id),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _photo(context),
                      // Over the photo rather than in the text column, so that
                      // a card without it has nothing moved.
                      if (km != null)
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: DistanceChip(km: km),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _photo(BuildContext context) {
    final photo = entry.photo;
    return photo != null && photo.isNotEmpty
        ? FadeInImage.assetNetwork(
          image: photo,
          fit: BoxFit.cover,
          placeholder: 'assets/images/church_blurred.png',
          imageErrorBuilder: _errorBuilder,
          imageCacheHeight: _decodeHeight(context),
          placeholderCacheHeight: _decodeHeight(context),
        )
        : Image.asset(
          'assets/images/church_blurred.png',
          fit: BoxFit.cover,
          cacheHeight: _decodeHeight(context),
        );
  }

  Widget _errorBuilder(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    return Image.asset(
      'assets/images/church_blurred.png',
      fit: BoxFit.cover,
      cacheHeight: _decodeHeight(context),
    );
  }

  /// The photo slot is a third of the card wide and the full card tall, so
  /// height is the axis [BoxFit.cover] scales by and needs no headroom.
  int _decodeHeight(BuildContext context) =>
      PhotoDecode.forSlot(context, height, tight: true);
}

/// Reserves [lines] lines of [style] for [child], whether it takes them or not:
/// an invisible run of empty lines sets the height, in the font and the text
/// scale the child is drawn in.
class _LineSlot extends StatelessWidget {
  const _LineSlot({
    required this.lines,
    required this.style,
    required this.child,
  });

  final int lines;
  final TextStyle? style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ExcludeSemantics(
          child: Visibility(
            visible: false,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: Text('\n' * (lines - 1), style: style),
          ),
        ),
        child,
      ],
    );
  }
}

/// Today's masses on a single line. Those that do not fit give way to one
/// [TimeChip.more]; how many fit depends on the card's actual width, which
/// differs from phone to phone.
class _MassChips extends StatelessWidget {
  const _MassChips({required this.masses});

  final List<CachedMass> masses;

  static const double _spacing = 4;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    final textScaler = MediaQuery.textScalerOf(context);
    final times = [
      for (final mass in masses) TimeOfDay.fromDateTime(mass.time),
    ];

    double chipWidth(String label) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      final width = painter.width + 2 * TimeChip.padding;
      painter.dispose();
      return width;
    }

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

        return Row(
          children: [
            for (var i = 0; i < fitting; i++) ...[
              if (i > 0) const SizedBox(width: _spacing),
              TimeChip(time: times[i]),
            ],
            if (fitting < times.length) ...[
              if (fitting > 0) const SizedBox(width: _spacing),
              const TimeChip.more(),
            ],
          ],
        );
      },
    );
  }
}

/// Opens the details page of [entry]. The page loads everything by id; the
/// entry only seeds the name, the map and the header until then.
void openChurchDetails(BuildContext context, ChurchListEntry entry) {
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
    MaterialPageRoute(builder: (context) => ChurchDetailsPage(church: church)),
  );
}
