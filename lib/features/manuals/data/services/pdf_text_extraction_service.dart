import 'dart:math' as math;

import 'package:pdfrx/pdfrx.dart';

import '../../domain/models/manual_page_text.dart';

class PdfTextExtractionService {
  Future<List<ManualPageText>> extractPreview({
    required String manualId,
    required String filePath,
    int maxPages = 10,
  }) async {
    if (maxPages < 1) {
      throw ArgumentError.value(maxPages, 'maxPages', 'Must be positive');
    }

    await pdfrxFlutterInitialize();

    final document = await PdfDocument.openFile(
      filePath,
      useProgressiveLoading: false,
    );

    try {
      final pageCount = math.min(maxPages, document.pages.length);
      final results = <ManualPageText>[];

      for (var index = 0; index < pageCount; index++) {
        final page = document.pages[index];
        final extractedText = await page.loadText();

        if (extractedText == null) {
          throw StateError('Could not load text for PDF page ${index + 1}');
        }

        results.add(
          ManualPageText(
            manualId: manualId,
            pdfPageNumber: index + 1,
            text: extractedText.fullText,
          ),
        );
      }

      return results;
    } finally {
      await document.dispose();
    }
  }

  Stream<ManualPageText> extractAll({
    required String manualId,
    required String filePath,
    required bool Function() isCancelled,
  }) async* {
    if (isCancelled()) {
      throw const ExtractionCancelled();
    }

    await pdfrxFlutterInitialize();

    final document = await PdfDocument.openFile(
      filePath,
      useProgressiveLoading: false,
    );

    try {
      for (var index = 0; index < document.pages.length; index++) {
        if (isCancelled()) {
          throw const ExtractionCancelled();
        }

        final extractedText = await document.pages[index].loadText();

        if (isCancelled()) {
          throw const ExtractionCancelled();
        }

        if (extractedText == null) {
          throw StateError('Could not extract text from PDF page ${index + 1}');
        }

        yield ManualPageText(
          manualId: manualId,
          pdfPageNumber: index + 1,
          text: extractedText.fullText,
        );
      }
    } finally {
      await document.dispose();
    }
  }
}

class ExtractionCancelled implements Exception {
  const ExtractionCancelled();
}
