import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:servicemate/features/manuals/data/services/manual_preparation_status_service.dart';
import 'package:servicemate/features/manuals/data/services/pdf_storage_service.dart';
import 'package:servicemate/features/manuals/domain/models/manual_readiness.dart';

void main() {
  const manualId = '11111111-1111-4111-8111-111111111111';

  late Directory documents;
  late Directory manualDirectory;
  late ManualPreparationStatusService service;

  Map<String, dynamic> validPassage() {
    return {
      'schemaVersion': 1,
      'id': '$manualId-p1-c0',
      'manualId': manualId,
      'pdfPageNumber': 1,
      'text': 'The default fridge temperature is 3 degrees Celsius.',
    };
  }

  Future<void> writePassage(Map<String, dynamic> record) async {
    await File(p.join(manualDirectory.path, 'chunks.jsonl'))
        .writeAsString('${jsonEncode(record)}\n');
  }

  setUp(() async {
    documents = await Directory.systemTemp.createTemp(
      'servicemate-readiness-test-',
    );

    manualDirectory = Directory(p.join(documents.path, 'manuals', manualId));

    await manualDirectory.create(recursive: true);

    // These tests check storage, not PDF parsing.
    await File(p.join(manualDirectory.path, 'manual.pdf'))
        .writeAsString('Test PDF placeholder');

    service = ManualPreparationStatusService(
      storageService: PdfStorageService(
        documentsDirectoryProvider: () async => documents,
      ),
    );
  });

  tearDown(() async {
    await documents.delete(recursive: true);
  });

  test('a manual without status or passages needs preparation', () async {
    expect(
      await service.getReadiness(manualId),
      ManualReadiness.needsPreparation,
    );
  });

  test('an older manual with valid passages is ready', () async {
    await writePassage(validPassage());

    expect(await service.getReadiness(manualId), ManualReadiness.ready);
  });

  test('ready status requires valid passages', () async {
    await writePassage(validPassage());

    await service.write(
      manualId: manualId,
      status: ManualPreparationStatus.ready,
    );

    expect(await service.getReadiness(manualId), ManualReadiness.ready);

    await File(p.join(manualDirectory.path, 'chunks.jsonl')).delete();

    expect(
      await service.getReadiness(manualId),
      ManualReadiness.needsPreparation,
    );
  });

  test('an empty passage file is not ready', () async {
    await File(p.join(manualDirectory.path, 'chunks.jsonl'))
        .writeAsString('\n  \n');

    await service.write(
      manualId: manualId,
      status: ManualPreparationStatus.ready,
    );

    expect(
      await service.getReadiness(manualId),
      ManualReadiness.needsPreparation,
    );
  });

  final outcomes = {
    ManualPreparationStatus.preparing: ManualReadiness.incomplete,
    ManualPreparationStatus.cancelled: ManualReadiness.cancelled,
    ManualPreparationStatus.noText: ManualReadiness.noText,
    ManualPreparationStatus.failed: ManualReadiness.failed,
  };

  for (final entry in outcomes.entries) {
    test('${entry.key.name} does not reuse old passages as ready', () async {
      await writePassage(validPassage());

      await service.write(manualId: manualId, status: entry.key);

      expect(await service.getReadiness(manualId), entry.value);
    });
  }

  test('rejects damaged status JSON', () async {
    await File(p.join(manualDirectory.path, 'preparation_status.json'))
        .writeAsString('{broken json');

    await expectLater(service.getReadiness(manualId), throwsFormatException);
  });

  test('rejects a passage belonging to another manual', () async {
    final record = validPassage();
    record['manualId'] = 'another-manual';

    await writePassage(record);

    await expectLater(service.getReadiness(manualId), throwsFormatException);
  });

  test('checks every passage, including records after a valid one', () async {
    final invalidRecord = validPassage();
    invalidRecord['pdfPageNumber'] = 0;

    await File(p.join(manualDirectory.path, 'chunks.jsonl')).writeAsString(
      '${jsonEncode(validPassage())}\n'
      '${jsonEncode(invalidRecord)}\n',
    );

    await expectLater(service.getReadiness(manualId), throwsFormatException);
  });
}
