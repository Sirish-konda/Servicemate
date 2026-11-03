import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:servicemate/features/chat/data/services/manual_answer_history_service.dart';
import 'package:servicemate/features/manuals/domain/models/manual_search_result.dart';

void main() {
  const manualId = '11111111-1111-4111-8111-111111111111';

  late Directory documents;
  late Directory manualDirectory;
  late ManualAnswerHistoryService service;

  setUp(() async {
    documents = await Directory.systemTemp.createTemp(
      'servicemate-history-test-',
    );

    manualDirectory = Directory(p.join(documents.path, 'manuals', manualId));

    await manualDirectory.create(recursive: true);

    // The history service checks existence; it does not parse the PDF.
    await File(p.join(manualDirectory.path, 'manual.pdf'))
        .writeAsString('Test PDF placeholder');

    service = ManualAnswerHistoryService(
      documentsDirectoryProvider: () async => documents,
    );
  });

  tearDown(() async {
    await documents.delete(recursive: true);
  });

  test('saves and reloads an answer with its sources', () async {
    final saved = await service.saveAnswer(
      manualId: manualId,
      question: 'What is the default fridge temperature?',
      answer: 'The default is 3 °C [1].',
      sources: [
        ManualSearchResult(
          pdfPageNumber: 28,
          snippet: 'The default fridge temperature is 3 °C.',
        ),
      ],
    );

    final result = await service.getAnswers(manualId);

    expect(result.unreadableCount, 0);
    expect(result.answers, hasLength(1));

    final loaded = result.answers.single;

    expect(loaded.id, saved.id);
    expect(loaded.manualId, manualId);
    expect(loaded.question, saved.question);
    expect(loaded.answer, saved.answer);
    expect(loaded.createdAt, saved.createdAt);
    expect(loaded.sources.single.pdfPageNumber, 28);
    expect(loaded.sources.single.snippet, saved.sources.single.snippet);
  });

  test('keeps readable answers when another JSON file is damaged', () async {
    final saved = await service.saveAnswer(
      manualId: manualId,
      question: 'How do I activate the lock?',
      answer: 'Hold the Lock button for 3 seconds [1].',
      sources: [
        ManualSearchResult(
          pdfPageNumber: 28,
          snippet: 'Press and hold the Lock button for 3 seconds.',
        ),
      ],
    );

    final damagedFile = File(
      p.join(
        manualDirectory.path,
        'answers',
        '22222222-2222-4222-8222-222222222222.json',
      ),
    );

    await damagedFile.writeAsString('{broken json');

    final result = await service.getAnswers(manualId);

    expect(result.answers, hasLength(1));
    expect(result.answers.single.id, saved.id);
    expect(result.unreadableCount, 1);

    // Loading history must not delete damaged records.
    expect(await damagedFile.exists(), isTrue);
  });

  test('deleting an answer preserves the PDF and other answers', () async {
    final first = await service.saveAnswer(
      manualId: manualId,
      question: 'First question?',
      answer: 'First answer.',
      sources: [],
    );

    final second = await service.saveAnswer(
      manualId: manualId,
      question: 'Second question?',
      answer: 'Second answer.',
      sources: [],
    );

    await service.deleteAnswer(manualId: manualId, answerId: first.id);

    final result = await service.getAnswers(manualId);

    expect(result.answers, hasLength(1));
    expect(result.answers.single.id, second.id);
    expect(
      await File(p.join(manualDirectory.path, 'manual.pdf')).exists(),
      isTrue,
    );
  });

  test('rejects an answer ID containing a path', () async {
    await expectLater(
      service.deleteAnswer(manualId: manualId, answerId: '../manual'),
      throwsArgumentError,
    );
  });
}
