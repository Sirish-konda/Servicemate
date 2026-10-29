import 'package:flutter/material.dart';
import 'package:servicemate/features/manuals/data/services/pdf_storage_service.dart';
import 'package:servicemate/features/manuals/domain/models/saved_manual.dart';

import '../../data/services/pdf_picker_service.dart';
import '../../domain/models/selected_pdf.dart';
import '../widgets/selected_pdf_card.dart';

class ImportManualScreen extends StatefulWidget {
  const ImportManualScreen({super.key});

  @override
  State<ImportManualScreen> createState() => _ImportManualScreenState();
}

class _ImportManualScreenState extends State<ImportManualScreen> {
  final PdfPickerService _pickerService = PdfPickerService();
  final PdfStorageService _storageService = PdfStorageService();

  SavedManual? _savedManual;
  SelectedPdf? _selectedPdf;

  bool _isSaving = false;
  bool _isPicking = false;

  Future<void> _pickPdf() async {
    if (_isPicking || _isSaving) return;

    setState(() {
      _isPicking = true;
    });

    try {
      final pdf = await _pickerService.pickPdf();

      if (!mounted) return;

      // Keep any existing selection if the user cancels.
      if (pdf != null) {
        setState(() {
          _selectedPdf = pdf;
          _savedManual = null;
        });
      }
    } on PdfPickerException catch (error) {
      if (!mounted) return;

      _showError(error.message);
    } catch (_) {
      if (!mounted) return;

      _showError('Could not select the PDF. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isPicking = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _removeSelection() {
    if (_isSaving) return;

    setState(() {
      _selectedPdf = null;
      _savedManual = null;
    });
  }

  Future<void> _saveManual() async {
    final pdf = _selectedPdf;

    if (pdf == null || _isSaving || _savedManual != null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final manual = await _storageService.savePdf(pdf);

      if (!mounted) return;

      setState(() {
        _savedManual = manual;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Manual saved on this device.')),
      );
    } catch (_) {
      if (!mounted) return;

      _showError(
        'Could not save the manual. Check available storage and try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final selectedPdf = _selectedPdf;

    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Import manual')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Text(
                'Add a PDF manual',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a PDF manual from your device.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: _isPicking || _isSaving ? null : _pickPdf,
                icon: _isPicking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file_outlined),
                label: Text(
                  _isPicking
                      ? 'Selecting PDF...'
                      : selectedPdf == null
                      ? 'Choose a PDF'
                      : 'Choose another PDF',
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(100),
                ),
              ),
              if (selectedPdf != null) ...[
                const SizedBox(height: 20),
                SelectedPdfCard(pdf: selectedPdf, onRemove: _removeSelection),
              ],
              const SizedBox(height: 28),
              Text(
                'What happens next?',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'After import is implemented, ServiceMate will save a local '
                'copy, extract its text and prepare it for searching.',
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed:
                    selectedPdf == null ||
                        _isPicking ||
                        _isSaving ||
                        _savedManual != null
                    ? null
                    : _saveManual,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _savedManual != null
                            ? 'Saved on this device. Text extraction has not been run yet.'
                            : 'Save a local copy before preparing the manual for search.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              Text(
                selectedPdf == null ? 'Select a PDF to preview its details.' : 'PDF selected. Saving and processing are not connected yet.',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
