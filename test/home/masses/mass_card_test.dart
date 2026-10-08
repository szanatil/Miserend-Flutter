import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/api/nearby_masses_item.dart';
import 'package:miserend/home/masses/mass_card.dart';
import 'package:miserend/mass_detail.dart';
import 'package:miserend/theme/miserend_theme.dart';
import 'package:miserend/theme/tokens.dart';
import 'package:miserend/widgets/distance_chip.dart';

import '../../theme/theme_harness.dart';

NearbyMassesItem _mass({
  String name = 'Szent Miklós-templom',
  String? city = 'Nyíregyháza',
  String? title = 'Szentmise',
  DateTime? start,
}) {
  return NearbyMassesItem(
    churchId: 1,
    churchName: name,
    city: city,
    lat: 47.95,
    lon: 21.72,
    distanceKm: 1.23,
    start: start ?? _at(18, 0),
    title: title,
  );
}

DateTime _at(int hour, int minute) => DateTime(2026, 9, 14, hour, minute);

/// The blurred church placeholder, looking through the resize wrapper that
/// decoding at the photo strip's size puts around it.
Finder _photo() => find.byWidgetPredicate((widget) {
  if (widget is! Image) return false;
  var provider = widget.image;
  if (provider is ResizeImage) provider = provider.imageProvider;
  return provider is AssetImage &&
      provider.assetName == 'assets/images/church_blurred.png';
});

/// The icon of a mass type, looking through the resize wrapper as [_photo]
/// does.
Finder _typeIcon(MassType type) => find.byWidgetPredicate((widget) {
  if (widget is! Image) return false;
  var provider = widget.image;
  if (provider is ResizeImage) provider = provider.imageProvider;
  return provider is AssetImage && provider.assetName == type.iconAsset;
});

/// A bubble of the mass detail.
Finder _bubble() => find.byType(MassDetailBubble);

void main() {
  Future<void> pumpCard(
    WidgetTester tester,
    NearbyMassesItem mass, {
    String? detail,
    double width = 400,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: miserendTheme(Brightness.light),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            // Scrollable as the list is, so a card taller than the screen
            // fits.
            body: SingleChildScrollView(
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: MassCard(
                    mass: mass,
                    detail: detail,
                    thumbnailUrl: Future.value(null),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('leaves the start to the header above it', (tester) async {
    await pumpCard(tester, _mass(start: _at(18, 0)));

    expect(find.text('18:00'), findsNothing);
  });

  group('church', () {
    testWidgets('writes the church name in titleMedium and the line under it '
        'in bodyMedium onSurfaceVariant (TI2)', (tester) async {
      await pumpCard(tester, _mass());

      final theme = Theme.of(tester.element(find.byType(MassCard)));
      expect(
        drawnStyle(tester, find.text('Szent Miklós-templom')).fontSize,
        theme.textTheme.titleMedium!.fontSize,
      );
      final place = drawnStyle(tester, find.text('Nyíregyháza'));
      expect(place.fontSize, theme.textTheme.bodyMedium!.fontSize);
      expect(place.color, theme.colorScheme.onSurfaceVariant);
    });

    testWidgets('leaves plain Szentmise out of the city line', (tester) async {
      await pumpCard(tester, _mass(title: 'Szentmise'));

      expect(find.text('Nyíregyháza'), findsOneWidget);
      expect(find.textContaining('Szentmise'), findsNothing);
    });

    testWidgets('puts any other title after the city', (tester) async {
      await pumpCard(tester, _mass(title: 'Szent Liturgia'));

      expect(find.text('Nyíregyháza · Szent Liturgia'), findsOneWidget);
    });

    testWidgets('shows the title alone when there is no city', (tester) async {
      await pumpCard(tester, _mass(city: null, title: 'Szent Liturgia'));

      expect(find.text('Szent Liturgia'), findsOneWidget);
    });

    testWidgets('keeps the detail off the city line', (tester) async {
      await pumpCard(
        tester,
        _mass(title: 'Szent Liturgia'),
        detail: 'latin nyelven',
      );

      expect(find.text('Nyíregyháza · Szent Liturgia'), findsOneWidget);
      expect(find.text('latin nyelven'), findsOneWidget);
    });

    testWidgets('puts each part of the detail in a bubble of its own, a type '
        'as its icon and its word', (tester) async {
      await pumpCard(
        tester,
        _mass(),
        detail: 'latin nyelven, Csendes (Mária-kápolnában)',
        width: 600,
      );

      for (final text in ['latin nyelven', 'Csendes', '(Mária-kápolnában)']) {
        expect(
          find.ancestor(of: find.text(text), matching: _bubble()),
          findsOneWidget,
          reason: text,
        );
      }
      expect(
        find.ancestor(of: _typeIcon(MassType.silent), matching: _bubble()),
        findsOneWidget,
      );
      expect(_bubble(), findsNWidgets(3));
    });

    testWidgets('a card without a detail has no bubble', (tester) async {
      await pumpCard(tester, _mass());

      expect(_bubble(), findsNothing);
    });

    testWidgets('tapping a bubble shows its whole text, and does not open the '
        'church', (tester) async {
      const comment =
          '(Minden hónap első péntekén a szentmise után Jézus Szíve '
          'litánia.)';
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: miserendTheme(Brightness.light),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: MassCard(
                  mass: _mass(),
                  detail: comment,
                  thumbnailUrl: Future.value(null),
                  onTap: () => taps++,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(_bubble());
      await tester.pump(const Duration(seconds: 1));

      // The bubble's own text, and the tooltip's over it.
      expect(find.text(comment), findsNWidgets(2));
      expect(taps, 0);
    });

    testWidgets('a long comment is cut off within its bubble, not '
        'overflowing the card', (tester) async {
      await pumpCard(
        tester,
        _mass(),
        detail:
            '(a Mária-kápolnában, adventben hajnali 6:00-kor, utána '
            'reggeli a plébánián)',
        width: 360,
      );

      expect(tester.takeException(), isNull);
      final card = tester.getRect(find.byType(MassCard));
      expect(tester.getRect(_bubble()).right, lessThanOrEqualTo(card.right));
    });

    for (final textScale in [1.0, 2.0, 3.0]) {
      testWidgets('a one-line detail leaves the card as tall as none at text '
          'scale $textScale', (tester) async {
        await pumpCard(tester, _mass(), width: 360, textScale: textScale);
        final without = tester.getSize(find.byType(MassCard)).height;

        await pumpCard(
          tester,
          _mass(),
          detail: 'Csendes',
          width: 360,
          textScale: textScale,
        );

        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(MassCard)).height, without);
      });

      testWidgets('bubbles that do not fit on one line all go on, and the card '
          'grows for them, at text scale $textScale', (tester) async {
        await pumpCard(tester, _mass(), width: 360, textScale: textScale);
        final without = tester.getSize(find.byType(MassCard)).height;

        await pumpCard(
          tester,
          _mass(),
          detail:
              'latin nyelven, Csendes, Gitáros, Diák, Énekes, '
              'Családos/mocorgós (Mária-kápolnában)',
          width: 360,
          textScale: textScale,
        );

        expect(tester.takeException(), isNull);
        expect(_bubble(), findsNWidgets(7));
        expect(
          tester.getSize(find.byType(MassCard)).height,
          greaterThan(without),
        );
      });
    }

    testWidgets('the line under the name stands at the same height for a short '
        'and a long name', (tester) async {
      await pumpCard(tester, _mass(name: 'Rövid'));
      final underShort = tester.getTopLeft(find.text('Nyíregyháza')).dy;

      await pumpCard(
        tester,
        _mass(
          name:
              'Nagyboldogasszony görögkatolikus székesegyház és '
              'püspöki templom',
        ),
      );
      final underLong = tester.getTopLeft(find.text('Nyíregyháza')).dy;

      expect(underLong, underShort);
    });

    testWidgets('long texts at a large text size do not overflow', (
      tester,
    ) async {
      await pumpCard(
        tester,
        _mass(
          name:
              'Nagyboldogasszony görögkatolikus székesegyház és '
              'püspöki templom',
          city: 'Budapest XVIII. kerület, Pestszentlőrinc-Pestszentimre',
          title: 'Régi rítusú szentmise',
          start: _at(18, 0),
        ),
        width: 360,
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('photo', () {
    testWidgets('runs the full height of the card to its right edge', (
      tester,
    ) async {
      await pumpCard(tester, _mass());

      // The card's surface, inside the margin around it.
      final card = tester.getRect(
        find
            .descendant(of: find.byType(Card), matching: find.byType(Material))
            .first,
      );
      final photo = tester.getRect(_photo());
      expect(photo.right, card.right);
      expect(photo.top, card.top);
      expect(photo.bottom, card.bottom);
    });

    testWidgets('carries the distance in its bottom right corner', (
      tester,
    ) async {
      await pumpCard(tester, _mass());

      final photo = tester.getRect(_photo());
      final chip = tester.getRect(find.byType(DistanceChip));
      expect(
        find.descendant(
          of: find.byType(DistanceChip),
          matching: find.text('1,2 km'),
        ),
        findsOneWidget,
      );
      expect(photo.right - chip.right, 8);
      expect(photo.bottom - chip.bottom, 8);
    });
  });

  testWidgets('has no favorite button', (tester) async {
    await pumpCard(tester, _mass());

    expect(find.byType(IconButton), findsNothing);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
  });

  testWidgets('tapping anywhere on the card calls onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: miserendTheme(Brightness.light),
        home: Scaffold(
          body: MassCard(
            mass: _mass(),
            thumbnailUrl: Future.value(null),
            onTap: () => taps++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Szent Miklós-templom'));
    await tester.tap(_photo());

    expect(taps, 2);
  });

  group('design', () {
    Future<void> pumpDesigned(
      WidgetTester tester, {
      Brightness brightness = Brightness.light,
      TargetPlatform platform = TargetPlatform.android,
      double width = 400,
      double textScale = 1,
      String? detail = 'latin nyelven, Csendes',
    }) async {
      await pumpThemed(
        tester,
        MassCard(
          mass: _mass(title: 'Szent Liturgia'),
          detail: detail,
          thumbnailUrl: Future.value(null),
        ),
        brightness: brightness,
        platform: platform,
        width: width,
        textScale: textScale,
      );
      await tester.pump();
    }

    for (final brightness in Brightness.values) {
      group('in $brightness', () {
        final scheme = schemeOf(brightness);

        testWidgets('the card is the theme card (KO1, MÉ1)', (tester) async {
          await pumpDesigned(tester, brightness: brightness);

          final surface = tester.widget<Material>(
            find
                .descendant(
                  of: find.byType(Card),
                  matching: find.byType(Material),
                )
                .first,
          );
          expect(surface.color, scheme.surfaceContainerLow);
          expect(surface.elevation, 0);
          expect(
            surface.shape,
            const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(Radii.m)),
            ),
          );
        });

        testWidgets('a bubble is secondaryContainer with 8 corners, its '
            'text and icon onSecondaryContainer (KO4)', (tester) async {
          await pumpDesigned(tester, brightness: brightness);

          final surface = tester.widget<DecoratedBox>(
            find.descendant(
              of: _bubble().last,
              matching: find.byType(DecoratedBox),
            ),
          );
          final decoration = surface.decoration as ShapeDecoration;
          expect(decoration.color, scheme.secondaryContainer);
          expect(
            decoration.shape,
            const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(Radii.s)),
            ),
          );
          expect(
            drawnStyle(tester, find.text('Csendes')).color,
            scheme.onSecondaryContainer,
          );
          final icon = tester.widget<Image>(_typeIcon(MassType.silent));
          expect(icon.color, scheme.onSecondaryContainer);
        });
      });
    }

    testWidgets('a bubble writes labelLarge beside an 18 icon (KO4, IK3)', (
      tester,
    ) async {
      await pumpDesigned(tester);

      final textTheme =
          Theme.of(tester.element(find.byType(MassCard))).textTheme;
      expect(
        drawnStyle(tester, find.text('Csendes')).fontSize,
        textTheme.labelLarge!.fontSize,
      );
      expect(tester.getSize(_typeIcon(MassType.silent)), const Size(18, 18));
    });

    testWidgets('keeps 16 inside its edge and 8 between the bubbles '
        '(KO1, TK2)', (tester) async {
      await pumpDesigned(tester, width: 600);

      final card = tester.getRect(
        find
            .descendant(of: find.byType(Card), matching: find.byType(Material))
            .first,
      );
      final name = tester.getRect(find.text('Szent Miklós-templom'));
      expect(name.left - card.left, Spacing.l);
      expect(name.top - card.top, Spacing.l);
      final first = tester.getRect(_bubble().first);
      final second = tester.getRect(_bubble().last);
      expect(second.left - first.right, Spacing.s);
    });

    testWidgets('nothing on it is larger or bolder than the start in its '
        'header (TI3)', (tester) async {
      await pumpDesigned(tester);

      final textTheme =
          Theme.of(tester.element(find.byType(MassCard))).textTheme;
      final start = textTheme.titleLarge!;
      for (final text
          in find
              .descendant(
                of: find.byType(MassCard),
                matching: find.byType(Text),
              )
              .evaluate()) {
        final style = drawnStyle(tester, find.byWidget(text.widget));
        expect(style.fontSize, lessThanOrEqualTo(start.fontSize!));
        expect(
          style.fontWeight!.value,
          lessThan(FontWeight.w600.value),
          reason: (text.widget as Text).data,
        );
      }
    });

    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      for (final width in eh4Widths) {
        for (final textScale in eh4TextScales) {
          testWidgets('fits $width dp at text scale $textScale on $platform '
              '(EH4)', (tester) async {
            await pumpDesigned(
              tester,
              platform: platform,
              width: width,
              textScale: textScale,
            );

            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });
}
