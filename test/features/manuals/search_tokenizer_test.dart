import 'package:flutter_test/flutter_test.dart';
import 'package:servicemate/features/manuals/data/services/search_tokenizer.dart';

void main() {
  final tokenizer = SearchTokenizer();

  test('normalises Wi-Fi spelling variants', () {
    for (final text in ['WiFi', 'Wi-Fi', 'Wi Fi', 'WI‑FI']) {
      expect(tokenizer.tokenize(text), ['wifi']);
    }
  });

  test('normalises frequency spacing and decimal separators', () {
    expect(tokenizer.tokenize('2.4 GHz'), ['2.4ghz', 'ghz']);

    expect(tokenizer.tokenize('2,4GHz'), ['2.4ghz', 'ghz']);

    expect(tokenizer.tokenize('5 GHz'), ['5ghz', 'ghz']);
  });

  test('removes common question words', () {
    expect(tokenizer.tokenize('What is the default fridge temperature?'), [
      'default',
      'fridge',
      'temperature',
    ]);
  });

  test('preserves equipment codes', () {
    expect(tokenizer.tokenize('Check error E-15'), contains('e-15'));
  });

  test('preserves German characters', () {
    expect(tokenizer.tokenize('Kühlschrank öffnen'), ['kühlschrank', 'öffnen']);
  });
}
