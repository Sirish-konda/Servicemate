import 'package:flutter/material.dart';

import '../../data/services/pdf_storage_service.dart';
import '../../data/services/pdf_text_extraction_service.dart';
import '../../domain/models/manual_page_text.dart';
import '../../domain/models/saved_manual.dart';

class ManualTextPreviewScreen extends StatefulWidget {
  const ManualTextPreviewScreen({super.key, required this.manual});

  final SavedManual manual;

  @override
  State<ManualTextPreviewScreen> createState() =>
      _ManualTextPreviewScreenState();
}

class _ManualTextPreviewScreenState extends State<ManualTextPreviewScreen> {
  final PdfStorageService _storageService = PdfStorageService();
  final PdfTextExtractionService _extractionService =
      PdfTextExtractionService();

  late Future<List<ManualPageText>> _previewFuture;

  @override
  void initState() {
    super.initState();
    _previewFuture = _loadPreview();
  }

  Future<List<ManualPageText>> _loadPreview() async {
    try {
      final filePath = await _storageService.getPdfPath(widget.manual.id);

      return await _extractionService.extractPreview(
        manualId: widget.manual.id,
        filePath: filePath,
      );
    } catch (error, stackTrace) {
      debugPrint('Text extraction failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  void _retry() {
    setState(() {
      _previewFuture = _loadPreview();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Text preview')),
      body: SafeArea(
        child: FutureBuilder<List<ManualPageText>>(
          future: _previewFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Reading the first 10 PDF pages...'),
                  ],
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Could not extract text from this PDF.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: _retry,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final pages = snapshot.data ?? [];

            if (pages.isEmpty) {
              return const Center(
                child: Text('This PDF has no pages to preview.'),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: pages.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Text(
                    '${widget.manual.name}\n\n'
                    'Showing ${pages.length} page(s), up to the first 10. '
                    'Compare this text with the original PDF. '
                    'Tables and columns may appear in the wrong order.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  );
                }

                return _PageTextCard(page: pages[index - 1]);
              },
            );
          },
        ),
      ),
    );
  }
}

class _PageTextCard extends StatelessWidget {
  const _PageTextCard({required this.page});

  final ManualPageText page;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PDF page ${page.pdfPageNumber}',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              page.hasText
                  ? page.text
                  : 'No text was extracted from this page. '
                        'It may contain an image, a scan or no text.',
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
