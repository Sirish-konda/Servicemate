import 'package:flutter/material.dart';

import '../../data/services/manual_preparation_service.dart';
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
  late final ManualPreparationService _preparationService;

  bool _isProcessing = false;
  bool _cancelRequested = false;
  bool _completed = false;

  int _pagesProcessed = 0;
  String _stage = '';

  String _message =
      'Prepare this manual so you can search its text '
      'and ask questions about it.';

  @override
  void initState() {
    super.initState();

    _preparationService = ManualPreparationService(
      storageService: PdfStorageService(),
    );
  }

  @override
  void dispose() {
    _cancelRequested = true;
    super.dispose();
  }

  Future<void> _prepare() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _cancelRequested = false;
      _completed = false;
      _pagesProcessed = 0;
      _stage = 'Opening the manual';
      _message = 'Preparing your manual...';
    });

    try {
      await _preparationService.prepare(
        manual: widget.manual,
        isCancelled: () => _cancelRequested,
        onProgress: (stage, pagesProcessed) {
          if (!mounted) return;

          setState(() {
            _stage = stage;
            _pagesProcessed = pagesProcessed;
          });
        },
      );

      if (!mounted) return;

      setState(() {
        _completed = true;
        _message =
            'Preparation complete. You can now search this manual '
            'and ask questions about its text.';
      });
    } on ExtractionCancelled {
      if (!mounted) return;

      setState(() {
        _message =
            'Preparation cancelled. Prepare the manual again '
            'to complete all steps.';
      });
    } on ManualHasNoTextException {
      if (!mounted) return;

      setState(() {
        _message =
            'No searchable text was found. This PDF may contain '
            'scanned pages that need OCR, which is not supported yet.';
      });
    } catch (error, stackTrace) {
      debugPrint('Manual preparation failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _message =
            'Could not prepare the manual. '
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

  void _cancel() {
    if (!_isProcessing || _cancelRequested) return;

    setState(() {
      _cancelRequested = true;
      _message = 'Cancelling after the current operation...';
    });
  }

  Future<void> _confirmAndPrepare() async {
    if (_isProcessing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Prepare this manual?'),
        content: const Text(
          'This extracts PDF text and builds searchable passages.\n\n'
          'If this manual was prepared before, its preparation data '
          'will be rebuilt. If rebuilding is interrupted, you may '
          'need to complete preparation before asking more questions.\n\n'
          'The PDF and saved answer history will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Prepare'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true || _isProcessing) return;

    await _prepare();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: !_isProcessing,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Prepare manual'),
          automaticallyImplyLeading: !_isProcessing,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(widget.manual.name, style: textTheme.titleLarge),
              const SizedBox(height: 24),
              if (_isProcessing) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 16),
                Text(_stage, style: textTheme.titleSmall),
                const SizedBox(height: 8),
                Text('$_pagesProcessed pages processed in this stage'),
                const SizedBox(height: 16),
              ],
              Text(_message),
              const SizedBox(height: 24),
              if (_isProcessing)
                OutlinedButton(
                  onPressed: _cancelRequested ? null : _cancel,
                  child: Text(_cancelRequested ? 'Cancelling...' : 'Cancel'),
                )
              else if (_completed)
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back to manual'),
                )
              else
                FilledButton(
                  onPressed: _confirmAndPrepare,
                  child: const Text('Prepare for questions'),
                ),
              const SizedBox(height: 20),
              const Text(
                'Preparation extracts existing PDF text and creates '
                'searchable passages on this device. It does not '
                'train or run the language model.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
