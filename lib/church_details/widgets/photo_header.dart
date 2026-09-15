import 'dart:async';

import 'package:flutter/material.dart';
import 'package:miserend/church_details/widgets/photo_gallery_page.dart';
import 'package:miserend/widgets/photo_decode.dart';

/// The photo strip behind the collapsing app bar.
///
/// With two or more photos it advances on its own, because a still image gives
/// no hint that there are others behind it. A swipe stops that for good: an
/// slideshow that resumes takes the photo out from under the person looking
/// at it.
class ChurchPhotoHeader extends StatefulWidget {
  const ChurchPhotoHeader({
    super.key,
    required this.photos,
    required this.height,
    required this.heroPrefix,
  });

  final List<String> photos;
  final double height;
  final String heroPrefix;

  @override
  State<ChurchPhotoHeader> createState() => _ChurchPhotoHeaderState();
}

class _ChurchPhotoHeaderState extends State<ChurchPhotoHeader>
    with WidgetsBindingObserver {
  static const Duration _interval = Duration(seconds: 4);
  static const String _placeholder = 'assets/images/church_blurred.png';

  final PageController _controller = PageController();
  Timer? _timer;
  int _index = 0;

  /// Set once the person swipes, and never cleared.
  bool _handedOver = false;

  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncTimer();
  }

  /// The page is built once before the cache read lands, so the photo list
  /// usually arrives after [initState] — without this the slideshow would never
  /// start on the churches that actually have more than one photo.
  @override
  void didUpdateWidget(ChurchPhotoHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photos.length != widget.photos.length) {
      if (_index >= widget.photos.length) {
        _index = 0;
      }
      _syncTimer();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _syncTimer(resumed: state == AppLifecycleState.resumed);
  }

  /// Runs only while there is something to advance through, the header is open,
  /// the app is in front, and the person has not taken over.
  void _syncTimer({bool resumed = true}) {
    final shouldRun =
        widget.photos.length > 1 &&
        !_handedOver &&
        !_collapsed &&
        resumed &&
        mounted;
    if (shouldRun && _timer == null) {
      _timer = Timer.periodic(_interval, (_) => _advance());
    } else if (!shouldRun) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _advance() {
    if (!mounted || !_controller.hasClients) {
      return;
    }
    final next = (_index + 1) % widget.photos.length;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _handOver() {
    if (_handedOver) {
      return;
    }
    _handedOver = true;
    _syncTimer();
  }

  @override
  Widget build(BuildContext context) {
    // FlexibleSpaceBar publishes how far the header is collapsed; there is no
    // point animating a 56px sliver of a photo behind the toolbar.
    final settings =
        context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    final collapsed =
        settings != null && settings.currentExtent <= settings.minExtent + 1.0;
    if (collapsed != _collapsed) {
      _collapsed = collapsed;
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncTimer());
    }

    if (widget.photos.isEmpty) {
      return Image.asset(
        _placeholder,
        fit: BoxFit.cover,
        cacheHeight: _decodeHeight(context),
      );
    }
    if (widget.photos.length == 1) {
      return GestureDetector(onTap: () => _openGallery(0), child: _photo(0));
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Listener(
          onPointerDown: (_) => _handOver(),
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.photos.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder:
                (context, index) => GestureDetector(
                  onTap: () => _openGallery(index),
                  child: _photo(index),
                ),
          ),
        ),
        Positioned(left: 0, right: 0, bottom: 8, child: _dots()),
      ],
    );
  }

  Widget _photo(int index) {
    return Hero(
      tag: '${widget.heroPrefix}-$index',
      child: FadeInImage.assetNetwork(
        image: widget.photos[index],
        fit: BoxFit.cover,
        placeholder: _placeholder,
        imageErrorBuilder:
            (context, error, stackTrace) => Image.asset(
              _placeholder,
              fit: BoxFit.cover,
              cacheHeight: _decodeHeight(context),
            ),
        imageCacheHeight: _decodeHeight(context),
        placeholderCacheHeight: _decodeHeight(context),
      ),
    );
  }

  Widget _dots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(widget.photos.length, (index) {
        final active = index == _index;
        return Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? Colors.white : Colors.white54,
          ),
        );
      }),
    );
  }

  void _openGallery(int index) {
    _handOver();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => PhotoGalleryPage(
              photos: widget.photos,
              initialIndex: index,
              heroPrefix: widget.heroPrefix,
            ),
      ),
    );
  }

  int _decodeHeight(BuildContext context) =>
      PhotoDecode.forSlot(context, widget.height);
}
