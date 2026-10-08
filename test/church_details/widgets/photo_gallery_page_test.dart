import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/church_details/widgets/photo_gallery_page.dart';
import 'package:miserend/theme/miserend_theme.dart';

import '../../theme/theme_harness.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('in $brightness, the gallery stands on the surface, not on a '
        'fixed black (SZ6)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: miserendTheme(brightness),
          home: const PhotoGalleryPage(
            photos: ['https://miserend.hu/a.jpg', 'https://miserend.hu/b.jpg'],
            initialIndex: 0,
            heroPrefix: 'church-38-photo',
          ),
        ),
      );
      final scheme = schemeOf(brightness);

      final ground = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(Scaffold),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(ground.color, scheme.surface);
      expect(drawnStyle(tester, find.text('1 / 2')).color, scheme.onSurface);
    });
  }
}
