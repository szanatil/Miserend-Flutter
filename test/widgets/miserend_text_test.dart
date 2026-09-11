import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/widgets/miserend_text.dart';

Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  group('normalize', () {
    test('is empty for nothing at all', () {
      expect(MiserendText.normalize(null), '');
      expect(MiserendText.normalize(''), '');
      expect(MiserendText.isEmpty('   '), isTrue);
    });

    test('decodes the entities the API encodes everything with', () {
      expect(MiserendText.normalize('Pl&eacute;b&aacute;nia &ndash; iroda'),
          'Plébánia – iroda');
    });

    test('turns a line break tag into a line break', () {
      expect(MiserendText.normalize('első<br />második<BR>harmadik'),
          'első\nmásodik\nharmadik');
    });

    test('handles tags before entities, so escaped markup survives as text', () {
      // &lt;br&gt; is the text "<br>", not a line break.
      expect(MiserendText.normalize('a &lt;br&gt; b'), 'a <br> b');
    });

    test('collapses the runs of blank padding lines', () {
      const raw = 'Cím:\r\n&nbsp;\r\n&nbsp;\r\n&nbsp;\r\n&nbsp;\r\nSzöveg';
      expect(MiserendText.normalize(raw), 'Cím:\n\nSzöveg');
    });

    test('strips a stray tag rather than showing it', () {
      expect(MiserendText.normalize('<p>Szöveg</p>'), 'Szöveg');
    });
  });

  group('against the recorded API responses', () {
    test('church 38 description loses its opening hole', () {
      final raw = _fixture('church_38.json')['leiras'] as String;
      final text = MiserendText.normalize(raw);

      // The raw field opens with seven &nbsp; lines in a row.
      expect(raw, contains('&nbsp;\r\n&nbsp;'));
      expect(text, startsWith('A Budapest-Belvárosi Nagyboldogasszony'));
      expect(text, isNot(contains('&')));
      expect(text, isNot(contains('\u00A0')));
      expect(text, isNot(contains('\n\n\n')));
    });

    test('church 2 mass schedule note keeps its line breaks', () {
      final raw = _fixture('church_2.json')['miserend_megjegyzes'] as String;
      final text = MiserendText.normalize(raw);

      expect(raw, contains('<br />'));
      expect(text, contains('\n'));
      expect(text, isNot(contains('<br')));
      expect(text, contains('akadálymentesített'));
    });

    test('church 2 parish block survives its markup', () {
      final text = MiserendText.normalize(
          _fixture('church_2.json')['plebania'] as String);

      expect(text, isNotEmpty);
      expect(text, isNot(contains('<br')));
      expect(text, isNot(contains('&nbsp;')));
    });
  });
}
