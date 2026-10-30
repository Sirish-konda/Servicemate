class SearchTokenizer {
  static const _stopWords = {
    'a',
    'an',
    'the',
    'is',
    'are',
    'was',
    'were',
    'what',
    'does',
    'do',
    'how',
    'can',
    'i',
    'my',
    'to',
    'of',
    'for',
    'please',
    'der',
    'die',
    'das',
    'ein',
    'eine',
    'ist',
    'sind',
    'wie',
    'ich',
    'mein',
    'meine',
    'bitte',
  };

  List<String> tokenize(String text) {
    var normalised = text.toLowerCase().replaceAll(
      RegExp(r'[\u2010-\u2015\u2212]'),
      '-',
    );

    normalised = normalised.replaceAll(RegExp(r'\bwi[\s-]*fi\b'), 'wifi');

    normalised = normalised.replaceAllMapped(
      RegExp(r'\b(\d+(?:[.,]\d+)?)\s*(ghz|mhz)\b'),
      (match) {
        final value = match.group(1)!.replaceAll(',', '.');
        final unit = match.group(2)!;

        return '$value$unit $unit';
      },
    );

    final pattern = RegExp(r'[a-zäöüß0-9]+(?:[._-][a-zäöüß0-9]+)*');

    return pattern
        .allMatches(normalised)
        .map((match) => match.group(0)!)
        .where((term) => !_stopWords.contains(term))
        .toList(growable: false);
  }
}
