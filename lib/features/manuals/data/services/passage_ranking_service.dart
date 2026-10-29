import 'package:servicemate/features/manuals/domain/models/manual_chunck.dart';

import '../../domain/models/manual_search_result.dart';

class PassageRankingService {
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

  Set<String> _terms(String text) {
    final pattern = RegExp(r'[a-zäöüß0-9]+(?:[-_][a-zäöüß0-9]+)*');

    return pattern
        .allMatches(text.toLowerCase())
        .map((match) => match.group(0)!)
        .toSet();
  }

  List<ManualSearchResult> rank({
    required List<ManualChunk> chunks,
    required String query,
    int maxResults = 30,
  }) {
    if (query.trim().isEmpty || maxResults < 1) {
      throw ArgumentError('Enter a query and a positive result limit.');
    }

    final queryTerms = _terms(query).difference(_stopWords);

    if (queryTerms.isEmpty) {
      return [];
    }

    final scored = <_ScoredChunk>[];
    final normalisedQuery = _normalise(query);

    for (final chunk in chunks) {
      final passageTerms = _terms(chunk.text);

      final matchedTerms = queryTerms
          .where(passageTerms.contains)
          .toList(growable: false);

      if (matchedTerms.isEmpty) continue;

      var score = matchedTerms.length;

      // Prefer a passage containing the complete query phrase.
      if (_normalise(chunk.text).contains(normalisedQuery)) {
        score += 3;
      }

      scored.add(
        _ScoredChunk(chunk: chunk, score: score, matchedTerms: matchedTerms),
      );
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
            snippet: _snippet(result.chunk.text, result.matchedTerms.first),
          );
        })
        .toList(growable: false);
  }

  String _normalise(String text) {
    return text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _snippet(String text, String term) {
    final match = RegExp(
      RegExp.escape(term),
      caseSensitive: false,
    ).firstMatch(text);

    final position = match?.start ?? 0;
    final start = position > 100 ? position - 100 : 0;
    final proposedEnd = (match?.end ?? position) + 180;
    final end = proposedEnd < text.length ? proposedEnd : text.length;

    final excerpt = text
        .substring(start, end)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return '${start > 0 ? '…' : ''}'
        '$excerpt'
        '${end < text.length ? '…' : ''}';
  }
}

class _ScoredChunk {
  const _ScoredChunk({
    required this.chunk,
    required this.score,
    required this.matchedTerms,
  });

  final ManualChunk chunk;
  final int score;
  final List<String> matchedTerms;
}
