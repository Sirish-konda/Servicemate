import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:servicemate/features/manuals/domain/models/manual_chunck.dart';

import '../../domain/models/manual_search_result.dart';
import 'passage_ranking_service.dart';
import 'pdf_storage_service.dart';

class ManualNotProcessedException implements Exception {
  const ManualNotProcessedException();
}

class ManualSearchService {
  ManualSearchService({required PdfStorageService storageService})
    : _storageService = storageService;

  final PdfStorageService _storageService;
  final PassageRankingService _rankingService = PassageRankingService();

  Future<List<ManualSearchResult>> search({
    required String manualId,
    required String query,
    int maxResults = 30,
  }) async {
    if (query.trim().isEmpty || maxResults < 1) {
      throw ArgumentError('Enter a query and a positive result limit.');
    }

    final pdfPath = await _storageService.getPdfPath(manualId);

    final chunksFile = File(p.join(p.dirname(pdfPath), 'chunks.jsonl'));

    if (!await chunksFile.exists()) {
      throw const ManualNotProcessedException();
    }

    final chunks = <ManualChunk>[];

    final lines = chunksFile
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
      final pageNumber = record['pdfPageNumber'];
      final text = record['text'];

      if (record['schemaVersion'] != 1 ||
          record['manualId'] != manualId ||
          id is! String ||
          pageNumber is! int ||
          pageNumber < 1 ||
          text is! String ||
          text.trim().isEmpty) {
        throw const FormatException('Invalid passage record.');
      }

      chunks.add(
        ManualChunk(
          id: id,
          manualId: manualId,
          pdfPageNumber: pageNumber,
          text: text,
        ),
      );
    }

    if (chunks.isEmpty) {
      throw const ManualNotProcessedException();
    }
    return _rankingService.rank(
      chunks: chunks,
      query: query,
      maxResults: maxResults,
    );
  }
}
