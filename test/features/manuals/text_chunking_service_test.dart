import 'package:flutter_test/flutter_test.dart';
import 'package:servicemate/features/manuals/data/services/text_chunking_service.dart';
import 'package:servicemate/features/manuals/domain/models/manual_page_text.dart';

void main() {
  final service = TextChunkingService();

  test('overlapping chunks retain all words and the source page', () {
    final chunks = service.createChunks(
      [
        ManualPageText(
          manualId: 'manual-1',
          pdfPageNumber: 7,
          text: List.generate(12, (index) => 'w${index + 1}').join(' '),
        ),
      ],
      maxWords: 5,
      overlapWords: 2,
    );

    expect(chunks.map((chunk) => chunk.text).toList(), [
      'w1 w2 w3 w4 w5',
      'w4 w5 w6 w7 w8',
      'w7 w8 w9 w10 w11',
      'w10 w11 w12',
    ]);

    expect(
      chunks.every(
        (chunk) => chunk.manualId == 'manual-1' && chunk.pdfPageNumber == 7,
      ),
      isTrue,
    );

    expect(chunks.map((chunk) => chunk.id).toSet().length, chunks.length);
  });

  test('skips empty pages without changing other page numbers', () {
    final chunks = service.createChunks(const [
      ManualPageText(manualId: 'manual-1', pdfPageNumber: 1, text: ' \n '),
      ManualPageText(
        manualId: 'manual-1',
        pdfPageNumber: 2,
        text: 'Fault E-47: Temperatur prüfen.',
      ),
    ]);

    expect(chunks.length, 1);
    expect(chunks.single.pdfPageNumber, 2);
    expect(chunks.single.text, 'Fault E-47: Temperatur prüfen.');
  });

  test('rejects overlap that would prevent forward progress', () {
    expect(
      () => service.createChunks([], maxWords: 10, overlapWords: 10),
      throwsArgumentError,
    );
  });
}
