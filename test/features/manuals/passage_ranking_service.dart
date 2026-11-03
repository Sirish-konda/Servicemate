import 'package:flutter_test/flutter_test.dart';
import 'package:servicemate/features/manuals/data/services/passage_ranking_service.dart';
import 'package:servicemate/features/manuals/domain/models/manual_chunck.dart';

ManualChunk passage({
  required String id,
  required int page,
  required String text,
}) {
  return ManualChunk(
    id: id,
    manualId: 'test-manual',
    pdfPageNumber: page,
    text: text,
  );
}

void main() {
  final ranking = PassageRankingService();

  final temperaturePassages = [
    passage(
      id: 'fridge',
      page: 10,
      text: 'The default fridge temperature is 3 degrees Celsius.',
    ),
    passage(
      id: 'freezer',
      page: 11,
      text: 'The default freezer temperature is -18 degrees Celsius.',
    ),
    passage(
      id: 'filter',
      page: 12,
      text: 'Replace the air filter approximately every twelve months.',
    ),
  ];

  test('ranks the fridge passage first for a fridge question', () {
    final results = ranking.rank(
      chunks: temperaturePassages,
      query: 'What is the default fridge temperature?',
    );

    expect(results, isNotEmpty);
    expect(results.first.pdfPageNumber, 10);
    expect(results.first.snippet, temperaturePassages.first.text);
  });

  test('ranks the freezer passage first for a freezer question', () {
    final results = ranking.rank(
      chunks: temperaturePassages,
      query: 'What is the default freezer temperature?',
    );

    expect(results, isNotEmpty);
    expect(results.first.pdfPageNumber, 11);
  });

  test('returns no results when there is no keyword overlap', () {
    final results = ranking.rank(
      chunks: temperaturePassages,
      query: 'bluetooth pairing',
    );

    expect(results, isEmpty);
  });

  test('respects the requested result limit', () {
    final results = ranking.rank(
      chunks: temperaturePassages,
      query: 'default temperature',
      maxResults: 1,
    );

    expect(results, hasLength(1));
  });

  test('matches Wi-Fi spelling and spaced frequency values', () {
    final results = ranking.rank(
      chunks: [
        passage(
          id: 'network',
          page: 20,
          text: 'The appliance uses Wi-Fi at 2.4 GHz.',
        ),
        passage(
          id: 'cleaning',
          page: 21,
          text: 'Clean the shelves with a soft cloth.',
        ),
      ],
      query: 'wifi 2.4ghz',
    );

    expect(results, hasLength(1));
    expect(results.single.pdfPageNumber, 20);
  });

  test('uses page number to order equal-scoring passages', () {
    final results = ranking.rank(
      chunks: [
        passage(id: 'later', page: 8, text: 'Clean the filter.'),
        passage(id: 'earlier', page: 4, text: 'Clean the filter.'),
      ],
      query: 'filter',
    );

    expect(
      results.map((result) => result.pdfPageNumber),
      orderedEquals([4, 8]),
    );
  });

  test('rejects an empty query', () {
    expect(
      () => ranking.rank(chunks: temperaturePassages, query: '   '),
      throwsArgumentError,
    );
  });

  test('rejects a non-positive result limit', () {
    expect(
      () => ranking.rank(
        chunks: temperaturePassages,
        query: 'fridge',
        maxResults: 0,
      ),
      throwsArgumentError,
    );
  });
}
