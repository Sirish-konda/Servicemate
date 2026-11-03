import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:servicemate/core/llm/model_storage_service.dart';

void main() {
  late Directory documents;
  late ModelStorageService service;

  Future<File> createFile(String relativePath, List<int> bytes) async {
    final file = File(p.join(documents.path, relativePath));

    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);

    return file;
  }

  setUp(() async {
    documents = await Directory.systemTemp.createTemp(
      'servicemate-model-storage-test-',
    );

    service = ModelStorageService(
      documentsDirectoryProvider: () async => documents,
    );
  });

  tearDown(() async {
    await documents.delete(recursive: true);
  });

  test('returns zero when the models folder does not exist', () async {
    final summary = await service.getSummary();

    expect(summary.fileCount, 0);
    expect(summary.totalBytes, 0);
  });

  test('counts models at the root and in installation folders', () async {
    await createFile(p.join('models', 'older.litertlm'), [1, 2, 3]);

    await createFile(p.join('models', 'qwen3-test', 'replacement.litertlm'), [
      4,
      5,
    ]);

    final summary = await service.getSummary();

    expect(summary.fileCount, 2);
    expect(summary.totalBytes, 5);
  });

  test('ignores unrelated files and files outside models', () async {
    await createFile(p.join('models', 'model.litertlm'), [1, 2, 3]);

    await createFile(p.join('models', 'metadata.json'), [4, 5]);

    await createFile(p.join('downloads', 'model.litertlm'), [6, 7, 8, 9]);

    final summary = await service.getSummary();

    expect(summary.fileCount, 1);
    expect(summary.totalBytes, 3);
  });

  test('recognises uppercase extensions', () async {
    await createFile(p.join('models', 'model.LITERTLM'), [1, 2]);

    final summary = await service.getSummary();

    expect(summary.fileCount, 1);
    expect(summary.totalBytes, 2);
  });

  test('does not change model files while measuring storage', () async {
    final file = await createFile(p.join('models', 'model.litertlm'), [
      10,
      20,
      30,
    ]);

    await service.getSummary();

    expect(await file.readAsBytes(), [10, 20, 30]);
  });
}
