import 'package:flutter/material.dart';

/// Full-screen view of a church's photos, pushed from the details header.
class PhotoGalleryPage extends StatefulWidget {
  const PhotoGalleryPage({
    super.key,
    required this.photos,
    required this.initialIndex,
    required this.heroPrefix,
  });

  final List<String> photos;
  final int initialIndex;
  final String heroPrefix;

  @override
  State<PhotoGalleryPage> createState() => _PhotoGalleryPageState();
}

class _PhotoGalleryPageState extends State<PhotoGalleryPage> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title:
            widget.photos.length > 1
                ? Text('${_index + 1} / ${widget.photos.length}')
                : null,
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.photos.length,
        onPageChanged: (index) => setState(() => _index = index),
        itemBuilder: (context, index) {
          return Center(
            child: Hero(
              tag: '${widget.heroPrefix}-$index',
              child: Image.network(
                widget.photos[index],
                fit: BoxFit.contain,
                errorBuilder:
                    (context, error, stackTrace) => Image.asset(
                      'assets/images/church_blurred.png',
                      fit: BoxFit.contain,
                    ),
              ),
            ),
          );
        },
      ),
    );
  }
}
