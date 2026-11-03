import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ModelStorageSummary {
  const ModelStorageSummary({
    required this.fileCount,
    required this.totalBytes,
  });

  final int fileCount;
  final int totalBytes;
}

class ModelStorageService {
  ModelStorageService({
    Future<Directory> Function()? documentsDirectoryProvider,
  }) : _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirectoryProvider;

  Future<ModelStorageSummary> getSummary() async {
    final documents = await _documentsDirectoryProvider();
    final directory = Directory(p.join(documents.path, 'models'));

    if (!await directory.exists()) {
      return const ModelStorageSummary(fileCount: 0, totalBytes: 0);
    }

    var fileCount = 0;
    var totalBytes = 0;

    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File ||
          p.extension(entity.path).toLowerCase() != '.litertlm') {
        continue;
      }

      totalBytes += await entity.length();
      fileCount++;
    }

    return ModelStorageSummary(fileCount: fileCount, totalBytes: totalBytes);
  }
}
