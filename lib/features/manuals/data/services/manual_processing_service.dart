import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'pdf_storage_service.dart';
import 'pdf_text_extraction_service.dart';

class ManualProcessingService {
  ManualProcessingService({
    required PdfStorageService storageService,
    required PdfTextExtractionService extractionService,
  }) : _storageService = storageService,
       _extractionService = extractionService;

  final PdfStorageService _storageService;
  final PdfTextExtractionService _extractionService;

  Future<int> process({
    required String manualId,
    required bool Function() isCancelled,
    required void Function(int pagesProcessed) onProgress,
  }) async {
    final pdfPath = await _storageService.getPdfPath(manualId);
    final directory = p.dirname(pdfPath);

    final temporaryFile = File(
      p.join(directory, 'pages-${const Uuid().v4()}.tmp'),
    );

    final outputPath = p.join(directory, 'pages.jsonl');

    try {
      final writer = await temporaryFile.open(mode: FileMode.write);
      var pagesProcessed = 0;

      try {
        await for (final page in _extractionService.extractAll(
          manualId: manualId,
          filePath: pdfPath,
          isCancelled: isCancelled,
        )) {
          final record = {
            'schemaVersion': 1,
            'manualId': page.manualId,
            'pdfPageNumber': page.pdfPageNumber,
            'text': page.text,
          };

          await writer.writeString('${jsonEncode(record)}\n', encoding: utf8);

          pagesProcessed++;
          onProgress(pagesProcessed);
        }

        await writer.flush();
      } finally {
        await writer.close();
      }

      if (isCancelled()) {
        throw const ExtractionCancelled();
      }

      await temporaryFile.rename(outputPath);

      return pagesProcessed;
    } finally {
      // A successful rename means the temporary path no longer exists.
      try {
        if (await temporaryFile.exists()) {
          await temporaryFile.delete();
        }
      } catch (_) {
        // Cleanup failure must not hide the processing result.
      }
    }
  }
}
