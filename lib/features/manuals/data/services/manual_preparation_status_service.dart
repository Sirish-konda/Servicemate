import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'pdf_storage_service.dart';

enum ManualPreparationStatus { preparing, ready, cancelled, noText, failed }

class ManualPreparationStatusService {
  ManualPreparationStatusService({required PdfStorageService storageService})
    : _storageService = storageService;

  final PdfStorageService _storageService;

  Future<void> write({
    required String manualId,
    required ManualPreparationStatus status,
  }) async {
    final pdfPath = await _storageService.getPdfPath(manualId);

    final file = File(p.join(p.dirname(pdfPath), 'preparation_status.json'));
    final temporaryFile = File('${file.path}.tmp');

    try {
      await temporaryFile.writeAsString(
        jsonEncode({
          'schemaVersion': 1,
          'manualId': manualId,
          'status': status.name,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        }),
        flush: true,
      );

      await temporaryFile.rename(file.path);
    } finally {
      if (await temporaryFile.exists()) {
        await temporaryFile.delete();
      }
    }
  }
}
