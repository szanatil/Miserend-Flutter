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
        const MaterialApp(
          home: MiserendMap(interactive: true),
        ),
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
        const MaterialApp(
          home: MiserendMap(interactive: true, apiKey: ''),
        ),
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
        const MaterialApp(
          home: MiserendMap(interactive: true),
        ),
      );

      expect(
        find.text('© OpenStreetMap contributors © CARTO'),
        findsOneWidget,
      );
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
      expect(
        find.text('© OpenStreetMap contributors © CARTO'),
        findsNothing,
      );
    });
  });

  group('MiserendMap markers', () {
    testWidgets('renders one Marker per entry in markers, at the given points', (
      WidgetTester tester,
    ) async {
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

      final markerLayer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
      expect(markerLayer.markers, hasLength(2));
      expect(markerLayer.markers[0].point, budapest);
      expect(markerLayer.markers[1].point, debrecen);
    });

    testWidgets('invokes onTap when a marker is tapped', (
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

      await tester.tap(find.byIcon(Icons.location_pin));
      expect(tapped, isTrue);
    });
  });

  group('MiserendMap interactivity', () {
    testWidgets('enables pan/zoom gestures when interactive is true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MiserendMap(interactive: true),
        ),
      );

      final flutterMap = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(
        flutterMap.options.interactionOptions.flags,
        InteractiveFlag.all,
      );
    });

    testWidgets('disables pan/zoom gestures when interactive is false', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MiserendMap(interactive: false),
        ),
      );

      final flutterMap = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(
        flutterMap.options.interactionOptions.flags,
        InteractiveFlag.none,
      );
    });
  });
}
