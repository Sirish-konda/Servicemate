import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:path_provider/path_provider.dart';
import 'package:servicemate/features/manuals/domain/models/saved_manual.dart';
import 'package:servicemate/features/manuals/domain/models/selected_pdf.dart';
import 'package:uuid/uuid.dart';

class ManualLibraryResult {
  ManualLibraryResult({
    required List<SavedManual> manuals,
    required this.unreadableCount,
  }) : manuals = List.unmodifiable(manuals);

  final List<SavedManual> manuals;
  final int unreadableCount;
}

class PdfStorageService {
  PdfStorageService({Future<Directory> Function()? documentsDirectoryProvider})
    : _documentsDirectoryProvider =
          documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirectoryProvider;

  Future<List<SavedManual>> getSavedManuals() async {
    final result = await getLibrary();
    return result.manuals;
  }

  Future<ManualLibraryResult> getLibrary() async {
    final documentsDirectory = await _documentsDirectoryProvider();

    final manualsDirectory = Directory(
      p.join(documentsDirectory.path, 'manuals'),
    );

    if (!await manualsDirectory.exists()) {
      return ManualLibraryResult(manuals: [], unreadableCount: 0);
    }

    final manuals = <SavedManual>[];
    var unreadableCount = 0;

    final validId = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );

    await for (final entity in manualsDirectory.list(followLinks: false)) {
      if (entity is! Directory) continue;

      final folderId = p.basename(entity.path);

      // Only UUID folders are part of our manual storage layout.
      if (!validId.hasMatch(folderId)) continue;

      try {
        final metadataFile = File(p.join(entity.path, 'metadata.json'));

        if (!await metadataFile.exists()) {
          unreadableCount++;
          continue;
        }

        final decoded = jsonDecode(await metadataFile.readAsString());

        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Invalid manual metadata.');
        }

        final id = decoded['id'];
        final name = decoded['name'];
        final sizeBytes = decoded['sizeBytes'];
        final importedAt = decoded['importedAt'];

        if (decoded['schemaVersion'] != 1 ||
            id is! String ||
            id != folderId ||
            name is! String ||
            name.trim().isEmpty ||
            sizeBytes is! int ||
            sizeBytes <= 0 ||
            importedAt is! String) {
          throw const FormatException('Invalid manual metadata fields.');
        }

        final importedDate = DateTime.tryParse(importedAt);

        if (importedDate == null) {
          throw const FormatException('Invalid manual import date.');
        }

        final pdfFile = File(p.join(entity.path, 'manual.pdf'));

        if (!await pdfFile.exists() || await pdfFile.length() == 0) {
          throw const FileSystemException(
            'The saved manual PDF is missing or empty.',
          );
        }

        manuals.add(
          SavedManual(
            id: id,
            name: name,
            sizeBytes: sizeBytes,
            importedAt: importedDate,
          ),
        );
      } on FormatException {
        unreadableCount++;
      } on FileSystemException {
        unreadableCount++;
      }
    }

    manuals.sort(
      (first, second) => second.importedAt.compareTo(first.importedAt),
    );

    return ManualLibraryResult(
      manuals: manuals,
      unreadableCount: unreadableCount,
    );
  }

  Future<SavedManual> savePdf(SelectedPdf selectedpdf) async {
    final sourceFile = File(selectedpdf.path);

    if (!await sourceFile.exists()) {
      throw const FileSystemException(
        'The selected file is no longer available.',
      );
    }

    final documentsDirectory = await _documentsDirectoryProvider();
    final id = const Uuid().v4();

    final manualDirectory = Directory(
      p.join(documentsDirectory.path, 'manuals', id),
    );

    try {
      await manualDirectory.create(recursive: true);

      final destinationPath = p.join(manualDirectory.path, 'manual.pdf');

      final copiedFile = await sourceFile.copy(destinationPath);
      final actualSize = await copiedFile.length();

      if (actualSize == 0) {
        throw const FileSystemException('The copied PDF is empty.');
      }

      final manual = SavedManual(
        id: id,
        name: selectedpdf.name,
        sizeBytes: actualSize,
        importedAt: DateTime.now().toUtc(),
      );

      final metadata = {
        'schemaVersion': 1,
        'id': manual.id,
        'name': manual.name,
        'sizeBytes': manual.sizeBytes,
        'importedAt': manual.importedAt.toIso8601String(),
      };

      final temporaryMetadata = File(
        p.join(manualDirectory.path, 'metadata.json.tmp'),
      );

      await temporaryMetadata.writeAsString(jsonEncode(metadata), flush: true);

      await temporaryMetadata.rename(
        p.join(manualDirectory.path, 'metadata.json'),
      );

      return manual;
    } catch (_) {
      // Remove an incomplete import if copying or metadata writing fails.
      try {
        if (await manualDirectory.exists()) {
          await manualDirectory.delete(recursive: true);
        }
      } catch (_) {
        // Preserve the original save error if cleanup also fails.
      }

      rethrow;
    }
  }

  Future<String> getPdfPath(String manualId) async {
    // Prevent an ID from being interpreted as a relative filesystem path.
    final validId = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );

    if (!validId.hasMatch(manualId)) {
      throw const FormatException('Invalid manual ID.');
    }

    final documentsDirectory = await _documentsDirectoryProvider();

    final pdfFile = File(
      p.join(documentsDirectory.path, 'manuals', manualId, 'manual.pdf'),
    );

    if (!await pdfFile.exists()) {
      throw const FileSystemException('The saved PDF could not be found.');
    }

    return pdfFile.path;
  }

  Future<void> deleteManual(String manualId) async {
    final validId = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );

    if (!validId.hasMatch(manualId)) {
      throw const FormatException('Invalid manual ID.');
    }

    final documentsDirectory = await _documentsDirectoryProvider();

    final manualDirectory = Directory(
      p.join(documentsDirectory.path, 'manuals', manualId),
    );

    if (await manualDirectory.exists()) {
      await manualDirectory.delete(recursive: true);
    }
  }
}
