import 'package:flutter/material.dart';
import 'package:miserend/home/churches/favorite_churches.dart';
import 'package:miserend/home/churches/near_churches_page.dart';
import 'package:miserend/home/widgets/section_bar.dart';

const List<Tab> tabs = <Tab>[Tab(text: 'Közeli'), Tab(text: 'Kedvencek')];

class ChurchesPage extends StatelessWidget {
  const ChurchesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: tabs.length,
      child: const Scaffold(
        appBar: SectionBar.tabs(tabs),
        body: TabBarView(
          children: [NearChurchesPage(), FavoriteChurchesPage()],
        ),
      ),
    );
  }
}
