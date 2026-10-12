import 'package:flutter/material.dart';

/// A church photo from the network, covering its slot, with a blurred asset
/// [placeholder] until it arrives. Every photo comes in with the same motion
/// (DESIGN.md MO1, MO2): the placeholder leaves in `Durations.short3`, the
/// photo enters in `Durations.medium1`. With reduced motion the photo takes
/// the placeholder's place at once (MO3). The photo is decoration to the
/// screen reader, as is the placeholder: the church's name stands beside it
/// (DESIGN.md AM5).
class PhotoFadeIn extends StatelessWidget {
  const PhotoFadeIn({
    super.key,
    required this.image,
    required this.placeholder,
    this.imageErrorBuilder,
    this.imageCacheHeight,
    this.placeholderCacheHeight,
  });

  /// The photo's URL.
  final String image;

  /// The asset shown until the photo arrives.
  final String placeholder;

  final ImageErrorWidgetBuilder? imageErrorBuilder;
  final int? imageCacheHeight;
  final int? placeholderCacheHeight;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Image.network(
        image,
        fit: BoxFit.cover,
        cacheHeight: imageCacheHeight,
        errorBuilder: imageErrorBuilder,
        excludeFromSemantics: true,
        frameBuilder:
            (context, child, frame, wasSynchronouslyLoaded) =>
                frame == null ? _placeholder() : child,
      );
    }
    return FadeInImage.assetNetwork(
      image: image,
      placeholder: placeholder,
      fit: BoxFit.cover,
      fadeInDuration: Durations.medium1,
      fadeInCurve: Easing.emphasizedDecelerate,
      fadeOutDuration: Durations.short3,
      fadeOutCurve: Easing.emphasizedAccelerate,
      imageErrorBuilder: imageErrorBuilder,
      imageCacheHeight: imageCacheHeight,
      placeholderCacheHeight: placeholderCacheHeight,
      excludeFromSemantics: true,
    );
  }

  Widget _placeholder() => Image.asset(
    placeholder,
    fit: BoxFit.cover,
    cacheHeight: placeholderCacheHeight,
    excludeFromSemantics: true,
  );
}
