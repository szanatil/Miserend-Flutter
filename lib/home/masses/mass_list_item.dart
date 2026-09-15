import 'package:flutter/material.dart';
import 'package:miserend/api/nearby_masses_item.dart';
import 'package:miserend/extentions.dart';
import 'package:miserend/widgets/photo_decode.dart';

/// "1,2 km": one decimal, with the Hungarian decimal comma.
String formatDistance(double km) =>
    '${km.toStringAsFixed(1).replaceAll('.', ',')} km';

/// One row of the nearest masses.
class MassListItem extends StatelessWidget {
  const MassListItem({
    super.key,
    required this.mass,
    required this.ongoing,
    required this.thumbnailUrl,
    this.onTap,
  });

  static const double _thumbnailSize = 72;
  static const String _placeholder = 'assets/images/church_blurred.png';

  /// The one title not worth repeating on every row.
  static const String _plainMassTitle = 'Szentmise';

  final NearbyMassesItem mass;
  final bool ongoing;

  /// The church's cached photo. The row is drawn with the placeholder until
  /// this resolves, so a slow cache never holds the list back.
  final Future<String?> thumbnailUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final title = mass.title;
    final showTitle = title != null && title != _plainMassTitle;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: SizedBox(
                width: _thumbnailSize,
                height: _thumbnailSize,
                child: _thumbnail(context),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mass.churchName ?? '?',
                      style: textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (mass.city != null)
                      Text(
                        mass.city!,
                        style: textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          TimeOfDay.fromDateTime(mass.start).to24hours(),
                          style: textTheme.headlineMedium,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          formatDistance(mass.distanceKm),
                          style: textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    if (ongoing || showTitle)
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (ongoing) _OngoingBadge(),
                          if (showTitle)
                            Text(title, style: textTheme.bodyMedium),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbnail(BuildContext context) {
    final int decodeHeight = PhotoDecode.forSlot(context, _thumbnailSize);
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
  }
}

class _OngoingBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Épp most tart',
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: colors.onPrimaryContainer),
      ),
    );
  }
}
