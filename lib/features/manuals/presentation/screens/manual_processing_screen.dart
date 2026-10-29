import 'package:flutter/material.dart';

import '../../data/services/manual_processing_service.dart';
import '../../data/services/pdf_storage_service.dart';
import '../../data/services/pdf_text_extraction_service.dart';
import '../../domain/models/saved_manual.dart';

class ManualProcessingScreen extends StatefulWidget {
  const ManualProcessingScreen({super.key, required this.manual});

  final SavedManual manual;

  @override
  State<ManualProcessingScreen> createState() => _ManualProcessingScreenState();
}

class _ManualProcessingScreenState extends State<ManualProcessingScreen> {
  late final ManualProcessingService _processingService;

  bool _isProcessing = false;
  bool _cancelRequested = false;
  int _pagesProcessed = 0;

  String _message = 'Extract and save text from every PDF page.';

  @override
  void initState() {
    super.initState();

    _processingService = ManualProcessingService(
      storageService: PdfStorageService(),
      extractionService: PdfTextExtractionService(),
    );
  }

  @override
  void dispose() {
    _cancelRequested = true;
    super.dispose();
  }

  Future<void> _startProcessing() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _cancelRequested = false;
      _pagesProcessed = 0;
      _message = 'Opening the manual...';
    });

    try {
      final count = await _processingService.process(
        manualId: widget.manual.id,
        isCancelled: () => _cancelRequested,
        onProgress: (count) {
          if (!mounted) return;

          setState(() {
            _pagesProcessed = count;
            _message = 'Extracting text...';
          });
        },
      );

      if (!mounted) return;

      setState(() {
        _message =
            'Completed: $count pages saved. '
            'Some pages may contain no extractable text.';
      });
    } on ExtractionCancelled {
      if (!mounted) return;

      setState(() {
        _message =
            'Processing cancelled. '
            'Any previous completed extraction was kept.';
      });
    } catch (error, stackTrace) {
      debugPrint('Manual processing failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _message =
            'Could not complete extraction. '
            'Check the PDF and available storage, then try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _cancelProcessing() {
    setState(() {
      _cancelRequested = true;
      _message = 'Cancelling after the current operation...';
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isProcessing,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Process manual'),
          automaticallyImplyLeading: !_isProcessing,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                widget.manual.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              if (_isProcessing) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 16),
                Text('$_pagesProcessed pages processed'),
                const SizedBox(height: 16),
              ],
              Text(_message),
              const SizedBox(height: 24),
              if (_isProcessing)
                OutlinedButton(
                  onPressed: _cancelRequested ? null : _cancelProcessing,
                  child: Text(_cancelRequested ? 'Cancelling...' : 'Cancel'),
                )
              else
                FilledButton(
                  onPressed: _startProcessing,
                  child: const Text('Extract and save text'),
                ),
              const SizedBox(height: 20),
              const Text(
                'This reads existing PDF text. Scanned pages need OCR. '
                'Extraction does not mean the manual is indexed for search.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
