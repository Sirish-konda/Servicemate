import '../../domain/models/saved_manual.dart';
import 'manual_chunking_service.dart';
import 'manual_processing_service.dart';
import 'pdf_storage_service.dart';
import 'pdf_text_extraction_service.dart';
import 'text_chunking_service.dart';

class ManualHasNoTextException implements Exception {
  const ManualHasNoTextException();
}

class ManualPreparationService {
  ManualPreparationService({required PdfStorageService storageService})
    : _processingService = ManualProcessingService(
        storageService: storageService,
        extractionService: PdfTextExtractionService(),
      ),
      _chunkingService = ManualChunkingService(
        storageService: storageService,
        chunkingService: TextChunkingService(),
      );

  final ManualProcessingService _processingService;
  final ManualChunkingService _chunkingService;

  Future<void> prepare({
    required SavedManual manual,
    required bool Function() isCancelled,
    required void Function(String stage, int pagesProcessed) onProgress,
  }) async {
    onProgress('Extracting PDF text', 0);

    await _processingService.process(
      manualId: manual.id,
      isCancelled: isCancelled,
      onProgress: (count) {
        onProgress('Extracting PDF text', count);
      },
    );

    if (isCancelled()) {
      throw const ExtractionCancelled();
    }

    onProgress('Creating search passages', 0);

    final chunkCount = await _chunkingService.buildChunks(
      manualId: manual.id,
      isCancelled: isCancelled,
      onProgress: (count) {
        onProgress('Creating search passages', count);
      },
    );

    if (chunkCount == 0) {
      throw const ManualHasNoTextException();
    }
  }
}
