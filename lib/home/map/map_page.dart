import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:miserend/database/church.dart';
import 'package:miserend/database/church_with_masses.dart';
import 'package:miserend/database/miserend_database.dart';
import 'package:miserend/home/churches/church_list_item.dart';
import 'package:miserend/location_provider.dart';
import 'package:miserend/widgets/miserend_map.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _controller = MapController();
  List<MiserendMapMarker> _markers = [];
  ChurchWithMasses? selectedChurch;

  @override
  void initState() {
    super.initState();
    _loadChurches();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MiserendMap(
          interactive: true,
          mapController: _controller,
          markers: _markers,
        ),
        selectedChurch != null
            ? Column(
                children: [
                  Expanded(child: Container()),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ChurchListItem(churchWithMasses: selectedChurch!),
                  ),
                ],
              )
            : Container(),
        Positioned(
          right: 8,
          bottom: selectedChurch != null ? 192 : 8,
          child: FloatingActionButton(
            onPressed: _goToMyPosition,
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }

  Future<void> _loadChurches() async {
    MiserendDatabase database = await MiserendDatabase.create();
    final churches = await database.getAllChurches();
    setState(() {
      _markers = churches
          .map((church) => MiserendMapMarker(
                id: church.id,
                point: church.location,
                onTap: () => _onTapped(church),
              ))
          .toList();
    });
    _goToMyPosition();
  }

  Future<void> _goToMyPosition() async {
    Position position = await LocationProvider.getPosition();
    _controller.move(LatLng(position.latitude, position.longitude), 14);
  }

  _onTapped(Church church) {
    _showChurchCard(church);
  }

  Future<void> _showChurchCard(Church church) async {
    ChurchWithMasses churchWithMasses = (await (await MiserendDatabase.create())
            .getChurches(<int>[church.id]))
        .first;
    setState(() {
      selectedChurch = churchWithMasses;
    });
  }
}
