import 'package:flutter_test/flutter_test.dart';
import 'package:miserend/database/cache/search_text.dart';

void main() {
  group('searchText', () {
    test('folds case and Hungarian accents alike', () {
      expect(searchText('MÁTYÁS'), 'matyas');
      expect(searchText('Mátyás'), 'matyas');
      expect(searchText('matyas'), 'matyas');
    });

    test('folds the long vowels onto their base letter', () {
      expect(searchText('ŐRSÉG ÜRÖM Ű'), 'orseg urom u');
    });

    test('folds the letters of the neighbouring languages', () {
      expect(
        searchText('Košice Žilina Ľubochňa ô ä'),
        'kosice zilina lubochna o a',
      );
      expect(
        searchText('Timișoara Târgu Mureș Brașov Ţ Ş'),
        'timisoara targu mures brasov t s',
      );
      expect(searchText('Đakovo Čakovec Łódź'), 'dakovo cakovec lodz');
      expect(searchText('Straße'), 'strasse');
    });

    test('keeps everything else as it is', () {
      expect(
        searchText('100% templom, Szent-Kereszt'),
        '100% templom, szent-kereszt',
      );
      expect(searchText('Церковь'), 'церковь');
    });
  });
}
