import 'package:flutter/material.dart';
import 'package:servicemate/features/manuals/data/services/manual_preparation_status_service.dart';
import 'package:servicemate/features/manuals/domain/models/manual_readiness.dart';
import 'package:servicemate/features/manuals/presentation/screens/manual_pdf_screen.dart';
import 'package:servicemate/features/manuals/presentation/screens/manual_processing_screen.dart';

import '../../data/services/pdf_storage_service.dart';
import '../../domain/models/saved_manual.dart';
import '../widgets/manual_list_card.dart';
import '../widgets/manuals_empty_state.dart';
import 'import_manual_screen.dart';

class ManualsScreen extends StatefulWidget {
  const ManualsScreen({super.key});

  @override
  State<ManualsScreen> createState() => _ManualsScreenState();
}

class _ManualsScreenState extends State<ManualsScreen> {
  final PdfStorageService _storageService = PdfStorageService();

  late Future<ManualLibraryResult> _manualsFuture;

  String? _deletingManualId;

  String _searchQuery = '';

  late final ManualPreparationStatusService _statusService;

  final Map<String, Future<ManualReadiness>> _statusFutures = {};

  Future<ManualReadiness> _statusFor(String manualId) {
    return _statusFutures.putIfAbsent(
      manualId,
      () => _statusService.getReadiness(manualId),
    );
  }

  @override
  void initState() {
    super.initState();

    _statusService = ManualPreparationStatusService(
      storageService: _storageService,
    );

    _manualsFuture = _storageService.getLibrary();
  }

  void _reloadManuals() {
    if (_deletingManualId != null) return;

    setState(() {
      _statusFutures.clear();
      _manualsFuture = _storageService.getLibrary();
    });
  }

  Future<void> _openImportScreen() async {
    if (_deletingManualId != null) return;
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const ImportManualScreen()));

    if (!mounted) return;

    _reloadManuals();
  }

  Future<void> _openManual(SavedManual manual) async {
    if (_deletingManualId != null) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ManualPdfScreen(manual: manual)),
    );

    if (!mounted) return;

    _reloadManuals();
  }

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();

    return '${localDate.day.toString().padLeft(2, '0')}/'
        '${localDate.month.toString().padLeft(2, '0')}/'
        '${localDate.year}';
  }

  Future<void> _deleteManual(SavedManual manual) async {
    if (_deletingManualId != null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete manual?'),
          content: Text(
            'Delete "${manual.name}", its extracted text, '
            'search passages, and saved answer history from ServiceMate?\n\n'
            'Your original PDF outside the app will not be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) return;

    setState(() {
      _deletingManualId = manual.id;
    });

    var message = 'Manual deleted from ServiceMate.';

    try {
      await _storageService.deleteManual(manual.id);
    } catch (error, stackTrace) {
      debugPrint('Manual deletion failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      message =
          'Could not fully delete the manual. '
          'The library will be refreshed.';
    } finally {
      if (mounted) {
        setState(() {
          _deletingManualId = null;
        });

        _reloadManuals();

        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  Future<void> _prepareManual(SavedManual manual) async {
    if (_deletingManualId != null) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ManualProcessingScreen(manual: manual)),
    );

    if (!mounted) return;

    _reloadManuals();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manuals'),
        actions: [
          IconButton(
            onPressed: _reloadManuals,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh manuals',
          ),
          IconButton(
            onPressed: _openImportScreen,
            icon: const Icon(Icons.add),
            tooltip: 'Import PDF',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search manuals...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: colors.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<ManualLibraryResult>(
                future: _manualsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Could not access your manual library. Please try again.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton(
                              onPressed: _reloadManuals,
                              child: const Text('Try again'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final result = snapshot.data!;
                  final manuals = result.manuals;
                  final query = _searchQuery.trim().toLowerCase();

                  final filteredManuals = manuals.where((manual) {
                    return manual.name.toLowerCase().contains(query);
                  }).toList();

                  final Widget content;

                  if (manuals.isEmpty) {
                    content = SingleChildScrollView(
                      child: ManualsEmptyState(
                        title: result.unreadableCount > 0
                            ? 'No readable manuals'
                            : 'No manuals yet',
                        description: result.unreadableCount > 0
                            ? 'Saved entries could not be loaded. '
                                  'You can retry or import a copy of the original PDF.'
                            : 'Tap the + button to import your first PDF.',
                      ),
                    );
                  } else if (filteredManuals.isEmpty) {
                    content = const SingleChildScrollView(
                      child: ManualsEmptyState(
                        title: 'No manuals found',
                        description: 'Try searching with a different name.',
                      ),
                    );
                  } else {
                    content = ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: filteredManuals.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final manual = filteredManuals[index];

                        return FutureBuilder<ManualReadiness>(
                          key: ValueKey(manual.id),
                          future: _statusFor(manual.id),
                          builder: (context, statusSnapshot) {
                            final isChecking =
                                statusSnapshot.connectionState !=
                                ConnectionState.done;

                            final readiness = statusSnapshot.hasError
                                ? ManualReadiness.unreadable
                                : statusSnapshot.data ??
                                      ManualReadiness.needsPreparation;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ManualListCard(
                                  title: manual.name,
                                  subtitle:
                                      'Imported ${_formatDate(manual.importedAt)}',
                                  supportingText: isChecking
                                      ? 'Checking preparation...'
                                      : readiness.label,
                                  isDeleting: _deletingManualId == manual.id,
                                  onDelete: _deletingManualId == null
                                      ? () => _deleteManual(manual)
                                      : null,
                                  onTap: () => _openManual(manual),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed:
                                        !isChecking && _deletingManualId == null
                                        ? () => _prepareManual(manual)
                                        : null,
                                    icon: const Icon(Icons.manage_search),
                                    label: Text(
                                      isChecking
                                          ? 'Checking...'
                                          : readiness.actionLabel,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (result.unreadableCount > 0)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                          child: Text(
                            result.unreadableCount == 1
                                ? '1 saved manual could not be loaded. '
                                      'Its remaining files have been left untouched.'
                                : '${result.unreadableCount} saved manuals could not '
                                      'be loaded. Their remaining files have been '
                                      'left untouched.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      Expanded(child: content),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
