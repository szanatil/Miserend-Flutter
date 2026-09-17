import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
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
    /// Around the Parliament, a few hundred metres apart: one clump at the
    /// country zoom, separate pins up close.
    const nearby = [
      LatLng(47.5070, 19.0450),
      LatLng(47.5090, 19.0470),
      LatLng(47.5050, 19.0430),
      LatLng(47.5080, 19.0420),
      LatLng(47.5060, 19.0480),
    ];
    final nearbyCentre = LatLng(47.5070, 19.0450);

    List<MiserendMapMarker> markersAt(
      List<LatLng> points, {
      void Function(int id)? onTap,
    }) => [
      for (var i = 0; i < points.length; i++)
        MiserendMapMarker(
          id: i + 1,
          point: points[i],
          onTap: onTap == null ? null : () => onTap(i + 1),
        ),
    ];

    /// The group layer keys both the pin's box and the pin inside it.
    Finder pin(Object id) {
      final keyed = find.byKey(MiserendMap.markerKey(id));
      return keyed.evaluate().isEmpty ? keyed : keyed.first;
    }

    Finder pinImages() => find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == MiserendMap.pinAsset,
    );

    Future<void> pumpMap(
      WidgetTester tester, {
      required List<MiserendMapMarker> markers,
      required double zoom,
      LatLng? center,
      Object? selectedMarkerId,
      LatLng? userPosition,
      MapController? controller,
      VoidCallback? onTap,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MiserendMap(
            interactive: true,
            mapController: controller,
            initialCenter: center ?? nearbyCentre,
            initialZoom: zoom,
            markers: markers,
            selectedMarkerId: selectedMarkerId,
            userPosition: userPosition,
            onTap: onTap,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('close churches at a far zoom are one group that says how '
        'many', (tester) async {
      await pumpMap(tester, markers: markersAt(nearby), zoom: 8);

      expect(find.text('5'), findsOneWidget);
      expect(pinImages(), findsNothing);
    });

    testWidgets('up close the same churches are separate pins, no group', (
      tester,
    ) async {
      await pumpMap(tester, markers: markersAt(nearby), zoom: 16);

      for (var id = 1; id <= nearby.length; id++) {
        expect(pin(id), findsOneWidget);
      }
      expect(pinImages(), findsNWidgets(nearby.length));
      expect(find.text('5'), findsNothing);
    });

    testWidgets('a lone church is a pin at every zoom, never a dot', (
      tester,
    ) async {
      await pumpMap(
        tester,
        markers: [MiserendMapMarker(id: 1, point: debrecen)],
        center: debrecen,
        zoom: 6,
      );

      expect(pin(1), findsOneWidget);
      expect(pinImages(), findsOneWidget);
    });

    testWidgets('tapping a group zooms in on it', (tester) async {
      final controller = MapController();
      await pumpMap(
        tester,
        markers: markersAt(nearby),
        zoom: 8,
        controller: controller,
      );

      await tester.tap(find.text('5'));
      await tester.pumpAndSettle();

      expect(controller.camera.zoom, greaterThan(8));
    });

    testWidgets('invokes onTap when a pin is tapped', (tester) async {
      Object? tapped;
      await pumpMap(
        tester,
        markers: markersAt(nearby, onTap: (id) => tapped = id),
        zoom: 16,
      );

      await tester.tap(pin(2));
      await tester.pumpAndSettle();

      expect(tapped, 2);
    });

    group('two churches on one spot', () {
      final sameSpot = [budapest, budapest];

      testWidgets('open up in a circle at the closest zoom, and either can be '
          'picked', (tester) async {
        Object? tapped;
        await pumpMap(
          tester,
          markers: markersAt(sameSpot, onTap: (id) => tapped = id),
          center: budapest,
          zoom: 19,
        );
        expect(find.text('2'), findsOneWidget);

        await tester.tap(find.text('2'));
        await tester.pumpAndSettle();

        expect(pin(1), findsOneWidget);
        expect(pin(2), findsOneWidget);
        expect(
          tester.getCenter(pin(1)),
          isNot(tester.getCenter(pin(2))),
          reason: 'spread apart, so that each can be aimed at',
        );

        await tester.tap(pin(2));
        await tester.pumpAndSettle();
        expect(tapped, 2);
      });

      testWidgets('close up again when the map is tapped', (tester) async {
        await pumpMap(
          tester,
          markers: markersAt(sameSpot),
          center: budapest,
          zoom: 19,
          onTap: () {},
        );
        await tester.tap(find.text('2'));
        await tester.pumpAndSettle();
        expect(pin(1), findsOneWidget);

        await tester.tapAt(const Offset(40, 40));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(pin(1), findsNothing);
        expect(find.text('2'), findsOneWidget);
      });

      testWidgets('close up on a map tap also from a zoom between steps', (
        tester,
      ) async {
        // A pinch leaves the zoom between steps; the group moves the camera to
        // a whole step before it opens out.
        await pumpMap(
          tester,
          markers: markersAt(sameSpot),
          center: budapest,
          zoom: 18.5,
          onTap: () {},
        );
        await tester.tap(find.text('2'));
        await tester.pumpAndSettle();
        expect(pin(1), findsOneWidget);

        await tester.tapAt(const Offset(40, 40));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(pin(1), findsNothing);
      });
    });

    testWidgets('the selected church stays an enlarged pin at a far zoom, '
        'outside the group', (tester) async {
      await pumpMap(
        tester,
        markers: markersAt(nearby),
        zoom: 8,
        selectedMarkerId: 3,
      );

      expect(
        find.text('4'),
        findsOneWidget,
        reason: 'the group counts the others only',
      );
      expect(pin(3), findsOneWidget);
      expect(pinImages(), findsOneWidget);
      expect(
        tester.getSize(pin(3)).height,
        greaterThan(40),
        reason: 'enlarged next to an ordinary pin',
      );
    });

    testWidgets('the selected church is drawn above the other churches', (
      tester,
    ) async {
      await pumpMap(
        tester,
        markers: markersAt(nearby),
        zoom: 16,
        selectedMarkerId: 3,
      );

      final children =
          tester.widget<FlutterMap>(find.byType(FlutterMap)).children;
      final selectedLayer = children.indexWhere(
        (layer) =>
            layer is MarkerLayer &&
            layer.markers.single.key == MiserendMap.markerKey(3),
      );
      expect(
        selectedLayer,
        greaterThan(
          children.indexWhere((layer) => layer is MarkerClusterLayerWidget),
        ),
      );
    });
  });

  group('MiserendMap user position', () {
    Finder userMark() => find.byKey(MiserendMap.userPositionKey);

    testWidgets('is not marked while the position is unknown', (
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

      expect(userMark(), findsNothing);
    });

    testWidgets('is marked on its own, never folded into a group of churches', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MiserendMap(
            interactive: true,
            initialCenter: budapest,
            initialZoom: 8,
            markers: [
              MiserendMapMarker(id: 1, point: budapest),
              MiserendMapMarker(id: 2, point: budapest),
            ],
            userPosition: budapest,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(userMark(), findsOneWidget);
      expect(find.text('2'), findsOneWidget, reason: 'the churches only');
      final layers = tester.widgetList<MarkerLayer>(find.byType(MarkerLayer));
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
