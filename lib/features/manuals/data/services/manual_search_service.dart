import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;

import '../../domain/models/manual_search_result.dart';
import 'pdf_storage_service.dart';

class ManualNotProcessedException implements Exception {
  const ManualNotProcessedException();
}

class ManualSearchService {
  ManualSearchService({required PdfStorageService storageService})
    : _storageService = storageService;

  final PdfStorageService _storageService;

  Future<List<ManualSearchResult>> search({
    required String manualId,
    required String query,
    int maxResults = 30,
  }) async {
    final trimmedQuery = query.trim();

    if (trimmedQuery.isEmpty || maxResults < 1) {
      throw ArgumentError('Enter a query and a positive result limit.');
    }

    final pdfPath = await _storageService.getPdfPath(manualId);
    final pagesFile = File(p.join(p.dirname(pdfPath), 'pages.jsonl'));

    if (!await pagesFile.exists()) {
      throw const ManualNotProcessedException();
    }

    final pattern = RegExp(RegExp.escape(trimmedQuery), caseSensitive: false);

    final results = <ManualSearchResult>[];

    final lines = pagesFile
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      if (line.trim().isEmpty) continue;

      final record = jsonDecode(line);

      if (record is! Map<String, dynamic>) {
        throw const FormatException('Invalid extracted page record.');
      }

      final pageNumber = record['pdfPageNumber'];
      final text = record['text'];

      if (record['schemaVersion'] != 1 ||
          record['manualId'] != manualId ||
          pageNumber is! int ||
          pageNumber < 1 ||
          text is! String) {
        throw const FormatException('Invalid extracted page record.');
      }

      final match = pattern.firstMatch(text);

      if (match == null) continue;

      final start = math.max(0, match.start - 100);
      final end = math.min(text.length, match.end + 180);

      final excerpt = text
          .substring(start, end)
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      results.add(
        ManualSearchResult(
          pdfPageNumber: pageNumber,
          snippet:
              '${start > 0 ? '…' : ''}$excerpt${end < text.length ? '…' : ''}',
        ),
      );

      if (results.length >= maxResults) {
        break;
      }
    }

    return results;
  }
}
