import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:miserend/database/church_with_masses.dart';
import 'package:miserend/database/miserend_database.dart';
import 'package:miserend/location_provider.dart';
import 'package:miserend/home/churches/church_list_item.dart';
import 'package:miserend/widgets/list_status_view.dart';

class NearChurchesPage extends StatefulWidget {
  const NearChurchesPage({super.key});

  @override
  State<NearChurchesPage> createState() => _NearChurchesPageState();
}

class _NearChurchesPageState extends State<NearChurchesPage>  with
    AutomaticKeepAliveClientMixin<NearChurchesPage>{

  List<ChurchWithMasses> churches = <ChurchWithMasses>[];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadChurches();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      color: Colors.black12,
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return const LoadingView(message: 'Közeli templomok betöltése...');
    }

    if (error != null) {
      return MessageView(message: error!);
    }

    if (churches.isEmpty) {
      return const MessageView(message: 'Nem találhatóak közeli templomok.');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: churches.length,
      itemBuilder: (BuildContext context, int index) {
        return ChurchListItem(churchWithMasses: churches[index]);
      },
    );
  }

  Future<void> loadChurches() async {
    List<ChurchWithMasses> list = <ChurchWithMasses>[];
    String? failure;
    try {
      MiserendDatabase db = await MiserendDatabase.create();
      Position position = await LocationProvider.getPosition();
      list = await db.getCloseChurchesWithMasses(
          position.latitude, position.longitude);
    } catch (_) {
      failure = 'Nem sikerült meghatározni a helyzetedet, '
          'ezért a közeli templomok nem jeleníthetőek meg.';
    }

    if (!mounted) {
      return;
    }
    setState(() {
      churches = list;
      error = failure;
      loading = false;
    });
  }

  @override
  bool get wantKeepAlive => true;
}
