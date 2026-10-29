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
}
