import 'package:flutter/material.dart';
import 'package:servicemate/features/manuals/data/services/manual_chunking_service.dart';
import 'package:servicemate/features/manuals/data/services/text_chunking_service.dart';

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

  late final ManualChunkingService _manualChunkingService;
  @override
  void initState() {
    super.initState();

    _processingService = ManualProcessingService(
      storageService: PdfStorageService(),
      extractionService: PdfTextExtractionService(),
    );

    _manualChunkingService = ManualChunkingService(
      storageService: PdfStorageService(),
      chunkingService: TextChunkingService(),
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

  Future<void> _createPassages() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _cancelRequested = false;
      _pagesProcessed = 0;
      _message = 'Creating search passages...';
    });

    try {
      final count = await _manualChunkingService.buildChunks(
        manualId: widget.manual.id,
        isCancelled: () => _cancelRequested,
        onProgress: (count) {
          if (!mounted) return;

          setState(() {
            _pagesProcessed = count;
          });
        },
      );

      if (!mounted) return;

      setState(() {
        _message = count == 0
            ? 'No passages were created. Check whether the PDF '
                  'contains extractable text.'
            : 'Saved $count search passages.';
      });
    } on ExtractionCancelled {
      if (!mounted) return;

      setState(() {
        _message = 'Passage creation cancelled.';
      });
    } catch (error, stackTrace) {
      debugPrint('Passage creation failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _message =
            'Could not create passages. '
            'Extract the manual text first, then try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
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
              if (!_isProcessing) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _createPassages,
                  child: const Text('Create search passages'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
