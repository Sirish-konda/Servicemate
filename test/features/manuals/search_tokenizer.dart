import 'package:flutter_test/flutter_test.dart';
import 'package:servicemate/features/manuals/data/services/search_tokenizer.dart';

void main() {
  final tokenizer = SearchTokenizer();

  test('normalises Wi-Fi spelling variations', () {
    expect(tokenizer.tokenize('WiFi'), ['wifi']);
    expect(tokenizer.tokenize('Wi-Fi'), ['wifi']);
    expect(tokenizer.tokenize('Wi Fi'), ['wifi']);
    expect(tokenizer.tokenize('Wi‑Fi'), ['wifi']);
  });

  test('preserves frequency values while retaining a shared unit', () {
    expect(tokenizer.tokenize('5 GHz'), ['5ghz', 'ghz']);
    expect(tokenizer.tokenize('2.4 GHz'), ['2.4ghz', 'ghz']);
  });

  test('keeps complete error codes', () {
    expect(tokenizer.tokenize('E-47 F30005'), ['e-47', 'f30005']);
  });
}
