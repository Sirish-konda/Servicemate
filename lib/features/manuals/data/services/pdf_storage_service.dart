import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:path_provider/path_provider.dart';
import 'package:servicemate/features/manuals/domain/models/saved_manual.dart';
import 'package:servicemate/features/manuals/domain/models/selected_pdf.dart';
import 'package:uuid/uuid.dart';

class PdfStorageService {
  Future<List<SavedManual>> getSavedManuals() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();

    final manualsDirectory = Directory(
      p.join(documentsDirectory.path, 'manuals'),
    );

    if (!await manualsDirectory.exists()) {
      return [];
    }
    final manuals = <SavedManual>[];

    await for (final entity in manualsDirectory.list(followLinks: false)) {
      if (entity is! Directory) {
        continue;
      }
      final metadataFile = File(p.join(entity.path, 'metadata.json'));

      if (!await metadataFile.exists()) {
        continue;
      }

      final decoded = jsonDecode(await metadataFile.readAsString());

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid manual metadata');
      }

      final id = decoded['id'];
      final name = decoded['name'];
      final sizeBytes = decoded['sizeBytes'];
      final importedAt = decoded['importedAt'];

      if (decoded['schemaVersion'] != 1 ||
          id is! String ||
          name is! String ||
          sizeBytes is! int ||
          importedAt is! String ||
          id != p.basename(entity.path)) {
        throw const FormatException('Invalid manual metadata');
      }

      final pdfFile = File(p.join(entity.path, 'manual.pdf'));

      if (!await pdfFile.exists()) {
        throw const FileSystemException('A saved manual PDF is missing.');
      }

      manuals.add(
        SavedManual(
          id: id,
          name: name,
          sizeBytes: sizeBytes,
          importedAt: DateTime.parse(importedAt),
        ),
      );
    }

    manuals.sort(
      (first, second) => second.importedAt.compareTo(first.importedAt),
    );

    return manuals;
  }

  Future<SavedManual> savePdf(SelectedPdf selectedpdf) async {
    final sourceFile = File(selectedpdf.path);

    if (!await sourceFile.exists()) {
      throw const FileSystemException(
        'The selected file is no longer available.',
      );
    }

    final documentsDirectory = await getApplicationDocumentsDirectory();
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

    final documentsDirectory = await getApplicationDocumentsDirectory();

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

    final documentsDirectory = await getApplicationDocumentsDirectory();

    final manualDirectory = Directory(
      p.join(documentsDirectory.path, 'manuals', manualId),
    );

    if (await manualDirectory.exists()) {
      await manualDirectory.delete(recursive: true);
    }
  }
}
