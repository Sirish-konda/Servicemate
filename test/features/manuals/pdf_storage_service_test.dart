
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:servicemate/features/manuals/data/services/pdf_storage_service.dart';

void main() {
  const firstId = '11111111-1111-4111-8111-111111111111';
  const secondId = '22222222-2222-4222-8222-222222222222';

  late Directory documents;
  late PdfStorageService service;

  Future<Directory> createManual({
    required String id,
    required DateTime importedAt,
    String name = 'Test manual.pdf',
  }) async {
    final directory = Directory(p.join(documents.path, 'manuals', id));

    await directory.create(recursive: true);

    final pdf = File(p.join(directory.path, 'manual.pdf'));
    await pdf.writeAsString('Test PDF placeholder');

    await File(p.join(directory.path, 'metadata.json')).writeAsString(
      jsonEncode({
        'schemaVersion': 1,
        'id': id,
        'name': name,
        'sizeBytes': await pdf.length(),
        'importedAt': importedAt.toUtc().toIso8601String(),
      }),
    );

    return directory;
  }

  setUp(() async {
    documents = await Directory.systemTemp.createTemp(
      'servicemate-library-test-',
    );

    service = PdfStorageService(
      documentsDirectoryProvider: () async => documents,
    );
  });

  tearDown(() async {
    await documents.delete(recursive: true);
  });

  test('a missing library returns an empty result', () async {
    final result = await service.getLibrary();

    expect(result.manuals, isEmpty);
    expect(result.unreadableCount, 0);
  });

  test('readable manuals are returned newest first', () async {
    await createManual(id: firstId, importedAt: DateTime.utc(2026, 1, 1));
    await createManual(id: secondId, importedAt: DateTime.utc(2026, 2, 1));

    final result = await service.getLibrary();

    expect(result.unreadableCount, 0);
    expect(
      result.manuals.map((manual) => manual.id),
      orderedEquals([secondId, firstId]),
    );
  });

  test('damaged metadata does not hide a readable manual', () async {
    await createManual(id: firstId, importedAt: DateTime.utc(2026, 1, 1));

    final damagedDirectory = await createManual(
      id: secondId,
      importedAt: DateTime.utc(2026, 2, 1),
    );

    final metadata = File(p.join(damagedDirectory.path, 'metadata.json'));
    await metadata.writeAsString('{broken json');

    final result = await service.getLibrary();

    expect(result.manuals.single.id, firstId);
    expect(result.unreadableCount, 1);

    // Reading the library must not repair or delete damaged files.
    expect(await metadata.readAsString(), '{broken json');
    expect(
      await File(p.join(damagedDirectory.path, 'manual.pdf')).exists(),
      isTrue,
    );

    // Existing Home and Chat callers remain compatible.
    final manuals = await service.getSavedManuals();
    expect(manuals.single.id, firstId);
  });

  test('a missing PDF is counted as unreadable', () async {
    final directory = await createManual(
      id: firstId,
      importedAt: DateTime.utc(2026, 1, 1),
    );

    await File(p.join(directory.path, 'manual.pdf')).delete();

    final result = await service.getLibrary();

    expect(result.manuals, isEmpty);
    expect(result.unreadableCount, 1);
  });

  test('an empty PDF is counted as unreadable', () async {
    final directory = await createManual(
      id: firstId,
      importedAt: DateTime.utc(2026, 1, 1),
    );

    await File(p.join(directory.path, 'manual.pdf')).writeAsString('');

    final result = await service.getLibrary();

    expect(result.manuals, isEmpty);
    expect(result.unreadableCount, 1);
  });

  test('a UUID folder without metadata is counted', () async {
    await Directory(p.join(documents.path, 'manuals', firstId))
        .create(recursive: true);

    final result = await service.getLibrary();

    expect(result.manuals, isEmpty);
    expect(result.unreadableCount, 1);
  });

  test('unrelated folders are ignored', () async {
    await Directory(p.join(documents.path, 'manuals', 'unrelated-folder'))
        .create(recursive: true);

    final result = await service.getLibrary();

    expect(result.manuals, isEmpty);
    expect(result.unreadableCount, 0);
  });
}
