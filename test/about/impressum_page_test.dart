import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/about/impressum_page.dart';

void main() {
  Future<List<Uri>> pumpPage(WidgetTester tester) async {
    // Tall enough for every section, so none is left unbuilt below the fold.
    tester.view.physicalSize = const Size(440, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final opened = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ImpressumPage(
          openLink: (uri) async {
            opened.add(uri);
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return opened;
  }

  testWidgets('names the publisher with its address', (tester) async {
    await pumpPage(tester);
    expect(find.text('Impresszum'), findsOneWidget);
    expect(
      find.text('Jézus Társasága Magyarországi Rendtartománya'),
      findsOneWidget,
    );
    expect(find.text('1085 Budapest, Horánszky u. 20.'), findsOneWidget);
    expect(find.textContaining('Szent József Hackathon'), findsOneWidget);
  });

  testWidgets('the publisher link opens jezsuita.hu', (tester) async {
    final opened = await pumpPage(tester);
    await tester.tap(find.text('jezsuita.hu'));
    await tester.pumpAndSettle();
    expect(opened.single, Uri.parse('https://jezsuita.hu'));
  });

  testWidgets('the source code link opens the repository', (tester) async {
    final opened = await pumpPage(tester);
    await tester.tap(find.text('A projekt a GitHubon'));
    await tester.pumpAndSettle();
    expect(
      opened.single,
      Uri.parse('https://github.com/szanatil/Miserend-Flutter'),
    );
  });

  testWidgets('the tax number is copied for the 1% offer', (tester) async {
    final copied = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') copied.add(call.arguments);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpPage(tester);

    expect(find.textContaining('Jézus Társasága Alapítvány'), findsOneWidget);
    await tester.tap(find.byTooltip('Adószám másolása'));
    await tester.pump();

    expect(copied.single, {'text': '18064333-2-42'});
    expect(find.text('Adószám vágólapra másolva'), findsOneWidget);
  });

  testWidgets('the licences tile opens the licence list', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.text('Felhasznált licencek'));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });
}
