
import 'package:servicemate/features/manuals/domain/models/manual_chunck.dart';

import '../../domain/models/manual_page_text.dart';

class TextChunkingService {
  List<ManualChunk> createChunks(
    List<ManualPageText> pages, {
    int maxWords = 200,
    int overlapWords = 30,
  }) {
    if (maxWords < 1) {
      throw ArgumentError('maxWords must be positive.');
    }

    if (overlapWords < 0 || overlapWords >= maxWords) {
      throw ArgumentError('overlapWords must be between 0 and maxWords - 1.');
    }

    final chunks = <ManualChunk>[];

    for (final page in pages) {
      final cleanedText = _cleanText(page.text);

      if (cleanedText.isEmpty) {
        continue;
      }

      final words = cleanedText.split(RegExp(r'\s+'));

      var start = 0;
      var chunkIndex = 0;

      while (start < words.length) {
        final proposedEnd = start + maxWords;
        final end = proposedEnd < words.length ? proposedEnd : words.length;

        chunks.add(
          ManualChunk(
            id: '${page.manualId}-p${page.pdfPageNumber}-c$chunkIndex',
            manualId: page.manualId,
            pdfPageNumber: page.pdfPageNumber,
            text: words.sublist(start, end).join(' '),
          ),
        );

        if (end == words.length) {
          break;
        }

        start = end - overlapWords;
        chunkIndex++;
      }
    }

    return chunks;
  }

  String _cleanText(String text) {
    return text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\u00A0', ' ')
        .trim();
  }
}
