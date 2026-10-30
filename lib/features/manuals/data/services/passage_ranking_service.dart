import 'dart:math' as math;

import 'package:servicemate/features/manuals/domain/models/manual_chunck.dart';

import '../../domain/models/manual_search_result.dart';
import 'search_tokenizer.dart';

class PassageRankingService {
  final SearchTokenizer _tokenizer = SearchTokenizer();

  static const double _k1 = 1.2;
  static const double _b = 0.75;

  List<ManualSearchResult> rank({
    required List<ManualChunk> chunks,
    required String query,
    int maxResults = 30,
  }) {
    if (query.trim().isEmpty || maxResults < 1) {
      throw ArgumentError('Enter a query and a positive result limit.');
    }

    if (chunks.isEmpty) return [];

    final queryTerms = _tokenizer.tokenize(query).toSet();

    if (queryTerms.isEmpty) return [];

    final documents = chunks
        .map((chunk) {
          final tokens = _tokenizer.tokenize(chunk.text);
          final frequencies = <String, int>{};

          for (final token in tokens) {
            frequencies[token] = (frequencies[token] ?? 0) + 1;
          }

          return _SearchDocument(
            chunk: chunk,
            length: tokens.length,
            frequencies: frequencies,
          );
        })
        .where((document) => document.length > 0)
        .toList();

    if (documents.isEmpty) return [];

    final averageLength =
        documents.fold<int>(0, (total, document) => total + document.length) /
        documents.length;

    final documentFrequencies = <String, int>{};

    for (final document in documents) {
      for (final term in document.frequencies.keys) {
        documentFrequencies[term] = (documentFrequencies[term] ?? 0) + 1;
      }
    }

    final scored = <_ScoredChunk>[];

    for (final document in documents) {
      var score = 0.0;

      for (final term in queryTerms) {
        final frequency = document.frequencies[term] ?? 0;

        if (frequency == 0) continue;

        final documentFrequency = documentFrequencies[term]!;

        final inverseDocumentFrequency = math.log(
          1 +
              (documents.length - documentFrequency + 0.5) /
                  (documentFrequency + 0.5),
        );

        final lengthNormalisation =
            1 - _b + _b * document.length / averageLength;

        score +=
            inverseDocumentFrequency *
            (frequency * (_k1 + 1)) /
            (frequency + _k1 * lengthNormalisation);
      }

      if (score > 0) {
        scored.add(_ScoredChunk(chunk: document.chunk, score: score));
      }
    }

    scored.sort((first, second) {
      final scoreComparison = second.score.compareTo(first.score);

      if (scoreComparison != 0) return scoreComparison;

      final pageComparison = first.chunk.pdfPageNumber.compareTo(
        second.chunk.pdfPageNumber,
      );

      if (pageComparison != 0) return pageComparison;

      return first.chunk.id.compareTo(second.chunk.id);
    });

    return scored
        .take(maxResults)
        .map((result) {
          return ManualSearchResult(
            pdfPageNumber: result.chunk.pdfPageNumber,
            snippet: result.chunk.text,
          );
        })
        .toList(growable: false);
  }
}

class _SearchDocument {
  const _SearchDocument({
    required this.chunk,
    required this.length,
    required this.frequencies,
  });

  final ManualChunk chunk;
  final int length;
  final Map<String, int> frequencies;
}

class _ScoredChunk {
  const _ScoredChunk({required this.chunk, required this.score});

  final ManualChunk chunk;
  final double score;
}
