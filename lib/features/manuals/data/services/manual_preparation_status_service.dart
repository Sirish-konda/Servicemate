import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:servicemate/features/manuals/domain/models/manual_readiness.dart';

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

  Future<ManualReadiness> getReadiness(String manualId) async {
    final pdfPath = await _storageService.getPdfPath(manualId);
    final directory = p.dirname(pdfPath);

    final statusFile = File(p.join(directory, 'preparation_status.json'));
    final chunksFile = File(p.join(directory, 'chunks.jsonl'));

    if (!await statusFile.exists()) {
      final hasPassages = await _hasValidPassages(chunksFile, manualId);

      return hasPassages
          ? ManualReadiness.ready
          : ManualReadiness.needsPreparation;
    }

    final decoded = jsonDecode(await statusFile.readAsString());

    if (decoded is! Map<String, dynamic> ||
        decoded['schemaVersion'] != 1 ||
        decoded['manualId'] != manualId ||
        decoded['updatedAt'] is! String ||
        DateTime.tryParse(decoded['updatedAt'] as String) == null) {
      throw const FormatException('Invalid preparation status.');
    }

    switch (decoded['status']) {
      case 'ready':
        final hasPassages = await _hasValidPassages(chunksFile, manualId);

        return hasPassages
            ? ManualReadiness.ready
            : ManualReadiness.needsPreparation;

      case 'preparing':
        return ManualReadiness.incomplete;

      case 'cancelled':
        return ManualReadiness.cancelled;

      case 'noText':
        return ManualReadiness.noText;

      case 'failed':
        return ManualReadiness.failed;

      default:
        throw const FormatException('Unknown preparation status.');
    }
  }

  Future<bool> _hasValidPassages(File file, String manualId) async {
    if (!await file.exists()) return false;

    var hasPassages = false;

    final lines = file
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      if (line.trim().isEmpty) continue;

      final record = jsonDecode(line);

      if (record is! Map<String, dynamic>) {
        throw const FormatException('Invalid passage record.');
      }

      final id = record['id'];
      final page = record['pdfPageNumber'];
      final text = record['text'];

      if (record['schemaVersion'] != 1 ||
          record['manualId'] != manualId ||
          id is! String ||
          id.trim().isEmpty ||
          page is! int ||
          page < 1 ||
          text is! String ||
          text.trim().isEmpty) {
        throw const FormatException('Invalid passage fields.');
      }

      hasPassages = true;
    }

    return hasPassages;
  }
}
