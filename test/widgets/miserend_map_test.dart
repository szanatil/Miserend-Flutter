import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miserend/widgets/miserend_map.dart';

void main() {
  const budapest = LatLng(47.4979, 19.0402);
  const debrecen = LatLng(47.5316, 21.6273);

  group('MiserendMap tile configuration', () {
    testWidgets('uses the CartoDB Voyager tile URL, subdomains and maxZoom', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: MiserendMap(interactive: true)),
      );

      final tileLayer = tester.widget<TileLayer>(find.byType(TileLayer));

      expect(
        tileLayer.urlTemplate,
        'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
      );
      expect(tileLayer.subdomains, ['a', 'b', 'c', 'd']);
      expect(tileLayer.maxZoom, 19);
    });

    testWidgets(
      'switches to the single-host, key-authenticated tile URL when apiKey is set',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: MiserendMap(interactive: true, apiKey: 'TEST_KEY'),
          ),
        );

        final tileLayer = tester.widget<TileLayer>(find.byType(TileLayer));

        expect(
          tileLayer.urlTemplate,
          'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png?key=TEST_KEY',
        );
        expect(tileLayer.subdomains, isEmpty);
        expect(tileLayer.maxZoom, 19);
      },
    );

    testWidgets('falls back to the free subdomain URL when apiKey is empty', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: MiserendMap(interactive: true, apiKey: '')),
      );

      final tileLayer = tester.widget<TileLayer>(find.byType(TileLayer));

      expect(
        tileLayer.urlTemplate,
        'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
      );
    });
  });

  group('MiserendMap attribution', () {
    testWidgets('shows the full attribution text by default', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: MiserendMap(interactive: true)),
      );

      expect(find.text('© OpenStreetMap contributors © CARTO'), findsOneWidget);
    });

    testWidgets('shows a compact attribution when compactAttribution is true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MiserendMap(interactive: false, compactAttribution: true),
        ),
      );

      expect(find.text('© OSM © CARTO'), findsOneWidget);
      expect(find.text('© OpenStreetMap contributors © CARTO'), findsNothing);
    });
  });

  group('MiserendMap markers', () {
    /// The churches' layer is the first one; the user's position gets its own.
    MarkerLayer churchLayer(WidgetTester tester) =>
        tester.widgetList<MarkerLayer>(find.byType(MarkerLayer)).first;

    Marker markerFor(WidgetTester tester, Object id) => churchLayer(
      tester,
    ).markers.singleWhere((marker) => (marker.key as ValueKey).value == id);

    /// A pin hangs above its point by its tip; a dot sits centred on it.
    bool isPin(Marker marker) => marker.alignment == Alignment.topCenter;

    testWidgets(
      'renders one Marker per entry in markers, at the given points',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MiserendMap(
              interactive: true,
              markers: [
                MiserendMapMarker(id: 1, point: budapest),
                MiserendMapMarker(id: 2, point: debrecen),
              ],
            ),
          ),
        );

        final markerLayer = churchLayer(tester);
        expect(markerLayer.markers, hasLength(2));
        expect(markerLayer.markers[0].point, budapest);
        expect(markerLayer.markers[1].point, debrecen);
      },
    );

    testWidgets('draws the miserend.hu pin from pinMinZoom up', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MiserendMap(
            interactive: true,
            initialCenter: budapest,
            initialZoom: MiserendMap.pinMinZoom,
            markers: [MiserendMapMarker(id: 1, point: budapest)],
          ),
        ),
      );

      expect(isPin(markerFor(tester, 1)), isTrue);
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName, MiserendMap.pinAsset);
    });

    testWidgets('shrinks the churches to dots below pinMinZoom', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MiserendMap(
            interactive: true,
            initialCenter: budapest,
            initialZoom: MiserendMap.pinMinZoom - 1,
            markers: [MiserendMapMarker(id: 1, point: budapest)],
          ),
        ),
      );

      expect(isPin(markerFor(tester, 1)), isFalse);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('swaps dots for pins when the camera crosses pinMinZoom', (
      WidgetTester tester,
    ) async {
      final controller = MapController();
      await tester.pumpWidget(
        MaterialApp(
          home: MiserendMap(
            interactive: true,
            mapController: controller,
            initialCenter: budapest,
            initialZoom: MiserendMap.pinMinZoom - 1,
            markers: [MiserendMapMarker(id: 1, point: budapest)],
          ),
        ),
      );
      expect(isPin(markerFor(tester, 1)), isFalse);

      controller.move(budapest, MiserendMap.pinMinZoom);
      await tester.pump();

      expect(isPin(markerFor(tester, 1)), isTrue);
    });

    testWidgets('invokes onTap when a pin is tapped', (
      WidgetTester tester,
    ) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: MiserendMap(
            interactive: true,
            initialCenter: budapest,
            initialZoom: 14,
            markers: [
              MiserendMapMarker(
                id: 1,
                point: budapest,
                onTap: () => tapped = true,
              ),
            ],
          ),
        ),
      );

      (markerFor(tester, 1).child as GestureDetector).onTap!();
      expect(tapped, isTrue);
    });

    testWidgets('a tap on a dot zooms in to pinMinZoom instead of opening the '
        'church', (WidgetTester tester) async {
      var tapped = false;
      final controller = MapController();

      await tester.pumpWidget(
        MaterialApp(
          home: MiserendMap(
            interactive: true,
            mapController: controller,
            initialCenter: budapest,
            initialZoom: MiserendMap.pinMinZoom - 2,
            markers: [
              MiserendMapMarker(
                id: 1,
                point: debrecen,
                onTap: () => tapped = true,
              ),
            ],
          ),
        ),
      );

      (markerFor(tester, 1).child as GestureDetector).onTap!();
      await tester.pump();

      expect(tapped, isFalse, reason: 'the card would be a guess at this zoom');
      expect(controller.camera.zoom, MiserendMap.pinMinZoom);
      expect(controller.camera.center, debrecen);
    });

    testWidgets('the selected church stays an enlarged pin below pinMinZoom, '
        'above the others', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MiserendMap(
            interactive: true,
            initialCenter: budapest,
            initialZoom: MiserendMap.pinMinZoom - 1,
            selectedMarkerId: 2,
            markers: [
              MiserendMapMarker(id: 1, point: budapest),
              MiserendMapMarker(id: 2, point: debrecen),
            ],
          ),
        ),
      );

      final markers = churchLayer(tester).markers;
      expect(
        (markers.last.key as ValueKey).value,
        2,
        reason: 'drawn last, so it paints above the rest',
      );
      expect(isPin(markers.last), isTrue);
      expect(isPin(markers.first), isFalse);
      expect(
        markers.last.height,
        greaterThan(markerFor(tester, 1).height),
        reason: 'enlarged next to an ordinary pin',
      );
    });
  });

  group('MiserendMap user position', () {
    testWidgets('has no layer of its own while the position is unknown', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MiserendMap(
            interactive: true,
            markers: [MiserendMapMarker(id: 1, point: budapest)],
          ),
        ),
      );

      expect(find.byType(MarkerLayer), findsOneWidget);
    });

    testWidgets('marks the position in a layer above the churches', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MiserendMap(
            interactive: true,
            initialCenter: budapest,
            initialZoom: 14,
            markers: [MiserendMapMarker(id: 1, point: debrecen)],
            userPosition: budapest,
          ),
        ),
      );

      final layers = tester.widgetList<MarkerLayer>(find.byType(MarkerLayer));
      expect(layers, hasLength(2));
      expect(layers.last.markers.single.point, budapest);
    });
  });

  group('MiserendMap interactivity', () {
    testWidgets('enables pan/zoom gestures when interactive is true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: MiserendMap(interactive: true)),
      );

      final flutterMap = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(flutterMap.options.interactionOptions.flags, InteractiveFlag.all);
    });

    testWidgets('disables pan/zoom gestures when interactive is false', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: MiserendMap(interactive: false)),
      );

      final flutterMap = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(flutterMap.options.interactionOptions.flags, InteractiveFlag.none);
    });
  });
}
