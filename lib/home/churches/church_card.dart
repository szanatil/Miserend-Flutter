import 'package:flutter/material.dart';
import 'package:miserend/api/api_result.dart';
import 'package:miserend/church_details/church_details_page.dart';
import 'package:miserend/colors.dart';
import 'package:miserend/database/cache/church_list_entry.dart';
import 'package:miserend/database/church.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/mass_kind.dart';
import 'package:miserend/widgets/offline_notice.dart';
import 'package:miserend/widgets/photo_decode.dart';
import 'package:miserend/widgets/time_chip.dart';
import 'package:provider/provider.dart';

/// One church of a list read from the cache: its names, today's masses and
/// its first photo. Tapping it opens the details page.
class ChurchCard extends StatelessWidget {
  const ChurchCard({
    super.key,
    required this.entry,
    this.failure,
    this.dataAsOf,
  });

  final ChurchListEntry entry;

  /// Set where the card stands alone — the map's — and its own refresh got no
  /// answer; a list marks itself once, above the rows, instead.
  final ApiFailure? failure;

  /// How old the church's data is, for the (i) explanation.
  final DateTime? dataAsOf;

  /// Height of the photo slot in logical pixels; the card is a fixed 176 tall.
  static const double _imageHeight = 176;

  @override
  Widget build(BuildContext context) {
    // Confession, adoration and the hours come back among the rows too; the
    // chips promise a mass (CONTEXT.md, „Napi miserend").
    final masses = entry.masses.where(isMass).toList();
    final photo = entry.photo;

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
            height: _imageHeight,
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
                              child: Text(
                                entry.name ?? '',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                          ),
                          if (failure != null)
                            OfflineInfoButton(failure: failure, asOf: dataAsOf),
                        ],
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            8.0,
                            0.0,
                            8.0,
                            8.0,
                          ),
                          child: Text(
                            entry.commonName ?? '',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Wrap(
                          spacing: 4,
                          children: [
                            for (final mass in masses)
                              TimeChip(time: TimeOfDay.fromDateTime(mass.time)),
                          ],
                        ),
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
                  child:
                      photo != null && photo.isNotEmpty
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
                          ),
                ),
              ],
            ),
          ),
        ),
      ),
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
      PhotoDecode.forSlot(context, _imageHeight, tight: true);
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
