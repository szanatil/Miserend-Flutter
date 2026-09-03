import 'package:flutter/material.dart';
import 'package:miserend/database/mass_with_church.dart';
import 'package:miserend/extentions.dart';
import 'package:miserend/widgets/photo_decode.dart';

class MassListItem extends StatelessWidget {
  const MassListItem({super.key, required this.massWithChurch});

  static const double _thumbnailSize = 72;

  final MassWithChurch massWithChurch;

  @override
  Widget build(BuildContext context) {
    final int decodeHeight = PhotoDecode.forSlot(context, _thumbnailSize);

    placeholderBuilder(
        BuildContext context, Object exception, StackTrace? stackTrace) {
      return Image.asset(
        'assets/images/church_blurred.png',
        fit: BoxFit.cover,
        cacheHeight: decodeHeight,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: SizedBox(
              width: _thumbnailSize,
              height: _thumbnailSize,
              child: FadeInImage.assetNetwork(
                image: massWithChurch.church.imageUrl ?? "",
                fit: BoxFit.cover,
                placeholder: 'assets/images/church_blurred.png',
                imageErrorBuilder: placeholderBuilder,
                imageCacheHeight: decodeHeight,
                placeholderCacheHeight: decodeHeight,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(massWithChurch.church.name ?? "?",
                      overflow: TextOverflow.ellipsis),
                  Text(
                      massWithChurch.mass.time?.to24hours() ?? "?",
                      style: Theme.of(context).textTheme.headlineLarge),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
