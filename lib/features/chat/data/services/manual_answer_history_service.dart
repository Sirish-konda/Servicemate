import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:servicemate/features/chat/domain/models/saved_manula_answer.dart';
import 'package:uuid/uuid.dart';

import '../../../manuals/domain/models/manual_search_result.dart';

class ManualAnswerHistoryService {
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  Future<SavedManualAnswer> saveAnswer({
    required String manualId,
    required String question,
    required String answer,
    required List<ManualSearchResult> sources,
  }) async {
    if (question.trim().isEmpty || answer.trim().isEmpty) {
      throw ArgumentError('The question and answer must not be empty.');
    }

    final directory = await _historyDirectory(manualId);
    await directory.create(recursive: true);

    final record = SavedManualAnswer(
      id: const Uuid().v4(),
      manualId: manualId,
      question: question.trim(),
      answer: answer.trim(),
      createdAt: DateTime.now().toUtc(),
      sources: sources,
    );

    final file = File(p.join(directory.path, '${record.id}.json'));
    final temporaryFile = File('${file.path}.tmp');

    try {
      await temporaryFile.writeAsString(
        jsonEncode(record.toJson()),
        flush: true,
      );

      await temporaryFile.rename(file.path);
    } finally {
      if (await temporaryFile.exists()) {
        await temporaryFile.delete();
      }
    }

    return record;
  }

  Future<List<SavedManualAnswer>> getAnswers(String manualId) async {
    final directory = await _historyDirectory(manualId);

    if (!await directory.exists()) {
      return [];
    }

    final answers = <SavedManualAnswer>[];

    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || p.extension(entity.path) != '.json') {
        continue;
      }

      final decoded = jsonDecode(await entity.readAsString());

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid answer history record.');
      }

      final record = SavedManualAnswer.fromJson(decoded);
      final filenameId = p.basenameWithoutExtension(entity.path);

      if (record.manualId != manualId || record.id != filenameId) {
        throw const FormatException('Answer history record mismatch.');
      }

      answers.add(record);
    }

    answers.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return List.unmodifiable(answers);
  }

  Future<Directory> _historyDirectory(String manualId) async {
    if (!_uuidPattern.hasMatch(manualId)) {
      throw ArgumentError.value(manualId, 'manualId', 'Invalid manual ID.');
    }

    final documents = await getApplicationDocumentsDirectory();
    final manualDirectory = Directory(
      p.join(documents.path, 'manuals', manualId),
    );

    final pdf = File(p.join(manualDirectory.path, 'manual.pdf'));

    if (!await pdf.exists()) {
      throw StateError('The saved manual no longer exists.');
    }

    return Directory(p.join(manualDirectory.path, 'answers'));
  }

  Future<void> deleteAnswer({
    required String manualId,
    required String answerId,
  }) async {
    if (!_uuidPattern.hasMatch(answerId)) {
      throw ArgumentError.value(answerId, 'answerId', 'Invalid answer ID.');
    }

    final directory = await _historyDirectory(manualId);
    final file = File(p.join(directory.path, '$answerId.json'));

    if (await file.exists()) {
      await file.delete();
    }
  }
}
