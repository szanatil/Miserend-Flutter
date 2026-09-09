import 'package:flutter/material.dart';
import 'package:miserend/church_details/church_details_page.dart';
import 'package:miserend/database/church.dart';
import 'package:miserend/database/church_with_masses.dart';
import 'package:miserend/database/favorites_service.dart';
import 'package:miserend/database/mass.dart';
import 'package:miserend/mass_filter.dart';
import 'package:miserend/widgets/photo_decode.dart';
import 'package:miserend/widgets/time_chip.dart';
import 'package:provider/provider.dart';

class ChurchListItem extends StatefulWidget {
  const ChurchListItem({super.key, required this.churchWithMasses});

  final ChurchWithMasses churchWithMasses;

  @override
  State<ChurchListItem> createState() => _ChurchListItemState();
}

class _ChurchListItemState extends State<ChurchListItem> {
  /// Height of the photo slot in logical pixels; the card is a fixed 176 tall.
  static const double _imageHeight = 176;

  List<Mass>? _masses;

  @override
  void didUpdateWidget(ChurchListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.churchWithMasses != widget.churchWithMasses) {
      _masses = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          splashColor: Colors.blue.withAlpha(30),
          onTap: () {
            _openDetails(church, context);
          },
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
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    8.0, 8.0, 8.0, 4.0),
                                child: Text(church.name ?? "",
                                    style:
                                        Theme.of(context).textTheme.titleLarge),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      8.0, 0.0, 8.0, 8.0),
                                  child: Text(church.commonName ?? "",
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Wrap(
                                    spacing: 4,
                                    children: List<Widget>.generate(masses.length,
                                        (index) {
                                      return TimeChip(time: masses[index].time);
                                    })),
                              ),
                              Container(color: Colors.grey, height: 1),
                              Consumer<FavoritesService>(
                                builder: (context, favoritesService, child) {
                                  return IconButton(
                                    icon: favoritesService.isFavorite(church.id)
                                        ? const Icon(Icons.favorite)
                                        : const Icon(Icons.favorite_border),
                                    color: Colors.grey,
                                    tooltip: 'Toggle favorite',
                                    onPressed: () {
                                      setState(() {
                                        _toggleFavorites(church.id);
                                      });
                                    },
                                  );
                                },
                              ),
                            ])),
                    Expanded(
                      flex: 1,
                      child: church.imageUrl?.isNotEmpty ?? false
                          ? FadeInImage.assetNetwork(
                              image: church.imageUrl ?? "",
                              fit: BoxFit.cover,
                              placeholder: 'assets/images/church_blurred.png',
                              imageErrorBuilder: _errorBuilder,
                              imageCacheHeight: _decodeHeight(context),
                              placeholderCacheHeight: _decodeHeight(context),
                            )
                          : Image.asset('assets/images/church_blurred.png',
                              fit: BoxFit.cover,
                              cacheHeight: _decodeHeight(context)),
                    ),
                  ])),
        ),
      ),
    );
  }

  Future<void> _toggleFavorites(int churchId) async {
    Provider.of<FavoritesService>(context, listen: false).toggle(churchId);
  }

  _openDetails(Church church, BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => ChurchDetailsPage(church: church)),
    );
  }

  Widget _errorBuilder(
      BuildContext context, Object error, StackTrace? stackTrace) {
    return Image.asset('assets/images/church_blurred.png',
        fit: BoxFit.cover, cacheHeight: _decodeHeight(context));
  }

  /// The photo slot is a third of the card wide and the full card tall, so
  /// height is the axis [BoxFit.cover] scales by and needs no headroom.
  int _decodeHeight(BuildContext context) =>
      PhotoDecode.forSlot(context, _imageHeight, tight: true);

  Church get church => widget.churchWithMasses.church;

  /// Filtered once per card rather than on every rebuild, since this used to
  /// run for every visible card on every scroll frame.
  List<Mass> get masses => _masses ??= MassFilter.filterMassListForDay(
      widget.churchWithMasses.masses, DateTime.now());
}
