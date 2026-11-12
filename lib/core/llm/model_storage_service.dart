import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';

class ModelStorageSummary {
  const ModelStorageSummary({
    required this.fileCount,
    required this.totalBytes,
  });

  final int fileCount;
  final int totalBytes;
}

class StoredModelFile {
  const StoredModelFile({
    required this.path,
    required this.relativePath,
    required this.sizeBytes,
    required this.isRegistered,
  });

  final String path;
  final String relativePath;
  final int sizeBytes;
  final bool isRegistered;
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

  Future<Set<String>> _registeredPaths() async {
    final names = (await FlutterEdgeAi.listInstalledModels()).toSet();

    // Protect active identities even if an install record is incomplete.
    names.addAll(
      FlutterEdgeAi.activeModelSpec?.files.map((file) => file.filename) ??
          <String>[],
    );

    final paths = <String>{};

    for (final name in names) {
      final path = await FlutterEdgeAi.getModelPath(name);
      final normalised = p.normalize(p.absolute(path));

      paths.add(normalised);

      if (await File(path).exists()) {
        paths.add(p.normalize(await File(path).resolveSymbolicLinks()));
      }
    }

    return paths;
  }

  Future<List<StoredModelFile>> getModelFiles() async {
    final documents = await _documentsDirectoryProvider();
    final directory = Directory(p.join(documents.path, 'models'));

    if (!await directory.exists()) return [];

    final root = await directory.resolveSymbolicLinks();
    final registered = await _registeredPaths();
    final files = <StoredModelFile>[];

    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File ||
          p.extension(entity.path).toLowerCase() != '.litertlm') {
        continue;
      }

      final resolved = p.normalize(await entity.resolveSymbolicLinks());

      if (!p.isWithin(root, resolved)) {
        throw StateError('A model file is outside the model storage folder.');
      }

      files.add(
        StoredModelFile(
          path: resolved,
          relativePath: p.relative(resolved, from: root),
          sizeBytes: await entity.length(),
          isRegistered: registered.contains(resolved),
        ),
      );
    }

    files.sort(
      (first, second) => first.relativePath.compareTo(second.relativePath),
    );

    return List.unmodifiable(files);
  }

  Future<void> deleteUnregisteredFile(String path) async {
    final documents = await _documentsDirectoryProvider();
    final directory = Directory(p.join(documents.path, 'models'));
    final root = await directory.resolveSymbolicLinks();

    if (await FileSystemEntity.type(path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw StateError('The selected model file is unavailable.');
    }

    final file = File(path);
    final resolved = p.normalize(await file.resolveSymbolicLinks());

    if (!p.isWithin(root, resolved) ||
        p.extension(resolved).toLowerCase() != '.litertlm') {
      throw StateError('Only model files inside model storage can be deleted.');
    }

    // Recheck immediately before deletion; do not trust the displayed list.
    final registered = await _registeredPaths();

    if (registered.contains(resolved)) {
      throw StateError('This model file is registered and cannot be deleted.');
    }

    await File(resolved).delete();

    // Leave directories untouched; never recursively delete model folders.
  }
}
