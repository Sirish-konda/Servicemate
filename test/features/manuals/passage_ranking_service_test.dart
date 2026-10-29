import 'package:flutter_test/flutter_test.dart';
import 'package:servicemate/features/manuals/data/services/passage_ranking_service.dart';
import 'package:servicemate/features/manuals/domain/models/manual_chunck.dart';

void main() {
  final service = PassageRankingService();

  ManualChunk chunk(String id, int page, String text) {
    return ManualChunk(
      id: id,
      manualId: 'manual-1',
      pdfPageNumber: page,
      text: text,
    );
  }

  test('ranks a passage matching more query terms first', () {
    final results = service.rank(
      chunks: [
        chunk('c1', 1, 'The drive has several specifications.'),
        chunk('c2', 2, 'Reset the drive using the reset procedure.'),
      ],
      query: 'How do I reset the drive?',
    );

    expect(results.first.pdfPageNumber, 2);
  });

  test('matches complete error codes without matching longer codes', () {
    final results = service.rank(
      chunks: [
        chunk('c1', 1, 'E-470 indicates a different fault.'),
        chunk('c2', 2, 'E-47 indicates a sensor fault.'),
      ],
      query: 'E-47',
    );

    expect(results.length, 1);
    expect(results.single.pdfPageNumber, 2);
  });

  test('does not repeat a passage when it matches several terms', () {
    final results = service.rank(
      chunks: [chunk('c1', 1, 'Reset the drive using the reset button.')],
      query: 'reset drive',
    );

    expect(results.length, 1);
  });

  test('returns no results when no useful terms match', () {
    final results = service.rank(
      chunks: [chunk('c1', 1, 'Motor maintenance instructions.')],
      query: 'battery replacement',
    );

    expect(results, isEmpty);
  });
}
