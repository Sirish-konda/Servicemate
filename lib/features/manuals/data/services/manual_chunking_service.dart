import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../domain/models/manual_page_text.dart';
import 'pdf_storage_service.dart';
import 'pdf_text_extraction_service.dart';
import 'text_chunking_service.dart';

class ManualChunkingService {
  ManualChunkingService({
    required PdfStorageService storageService,
    required TextChunkingService chunkingService,
  }) : _storageService = storageService,
       _chunkingService = chunkingService;

  final PdfStorageService _storageService;
  final TextChunkingService _chunkingService;

  Future<int> buildChunks({
    required String manualId,
    required bool Function() isCancelled,
    required void Function(int pagesProcessed) onProgress,
  }) async {
    final pdfPath = await _storageService.getPdfPath(manualId);
    final directory = p.dirname(pdfPath);
    final pagesFile = File(p.join(directory, 'pages.jsonl'));

    if (!await pagesFile.exists()) {
      throw StateError('Extract the manual text first.');
    }

    final temporaryFile = File(
      p.join(directory, 'chunks-${const Uuid().v4()}.tmp'),
    );

    try {
      final writer = await temporaryFile.open(mode: FileMode.write);
      var pagesProcessed = 0;
      var chunkCount = 0;

      try {
        final lines = pagesFile
            .openRead()
            .transform(utf8.decoder)
            .transform(const LineSplitter());

        await for (final line in lines) {
          if (isCancelled()) {
            throw const ExtractionCancelled();
          }

          if (line.trim().isEmpty) continue;

          final record = jsonDecode(line);

          if (record is! Map<String, dynamic>) {
            throw const FormatException('Invalid page record.');
          }

          final pageNumber = record['pdfPageNumber'];
          final text = record['text'];

          if (record['schemaVersion'] != 1 ||
              record['manualId'] != manualId ||
              pageNumber is! int ||
              pageNumber < 1 ||
              text is! String) {
            throw const FormatException('Invalid page record.');
          }

          final chunks = _chunkingService.createChunks([
            ManualPageText(
              manualId: manualId,
              pdfPageNumber: pageNumber,
              text: text,
            ),
          ]);

          for (final chunk in chunks) {
            final output = {
              'schemaVersion': 1,
              'id': chunk.id,
              'manualId': chunk.manualId,
              'pdfPageNumber': chunk.pdfPageNumber,
              'text': chunk.text,
              'maxWords': 200,
              'overlapWords': 30,
            };

            await writer.writeString('${jsonEncode(output)}\n', encoding: utf8);

            chunkCount++;
          }

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

      await temporaryFile.rename(p.join(directory, 'chunks.jsonl'));

      return chunkCount;
    } finally {
      try {
        if (await temporaryFile.exists()) {
          await temporaryFile.delete();
        }
      } catch (_) {
        // Preserve the original processing result.
      }
    }
  }
}
