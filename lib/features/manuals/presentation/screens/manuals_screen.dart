import 'package:flutter/material.dart';
import 'package:servicemate/features/manuals/data/services/manual_preparation_status_service.dart';
import 'package:servicemate/features/manuals/presentation/screens/manual_pdf_screen.dart';

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

  late Future<List<SavedManual>> _manualsFuture;

  String? _deletingManualId;

  String _searchQuery = '';

  late final ManualPreparationStatusService _statusService;

  final Map<String, Future<String>> _statusFutures = {};

  @override
  void initState() {
    super.initState();

    _statusService = ManualPreparationStatusService(
      storageService: _storageService,
    );

    _manualsFuture = _storageService.getSavedManuals();
  }

  void _reloadManuals() {
    if (_deletingManualId != null) return;

    setState(() {
      _statusFutures.clear();
      _manualsFuture = _storageService.getSavedManuals();
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
            'Delete "${manual.name}" and its extracted text '
            'from ServiceMate?\n\n'
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

  Future<String> _statusFor(String manualId) {
    return _statusFutures.putIfAbsent(
      manualId,
      () => _statusService.getStatusLabel(manualId),
    );
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
              child: FutureBuilder<List<SavedManual>>(
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
                              'Could not load your manuals. '
                              'A saved file may be missing or unreadable.',
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

                  final manuals = snapshot.data ?? [];
                  final query = _searchQuery.trim().toLowerCase();

                  final filteredManuals = manuals.where((manual) {
                    return manual.name.toLowerCase().contains(query);
                  }).toList();

                  if (manuals.isEmpty) {
                    return const SingleChildScrollView(
                      child: ManualsEmptyState(
                        title: 'No manuals yet',
                        description:
                            'Tap the + button to import your first PDF.',
                      ),
                    );
                  }

                  if (filteredManuals.isEmpty) {
                    return const SingleChildScrollView(
                      child: ManualsEmptyState(
                        title: 'No manuals found',
                        description: 'Try searching with a different name.',
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: filteredManuals.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final manual = filteredManuals[index];

                      return FutureBuilder<String>(
                        key: ValueKey(manual.id),
                        future: _statusFor(manual.id),
                        builder: (context, statusSnapshot) {
                          final String status;

                          if (statusSnapshot.connectionState !=
                              ConnectionState.done) {
                            status = 'Checking preparation...';
                          } else if (statusSnapshot.hasError) {
                            status =
                                'Preparation data unreadable — prepare again';
                          } else {
                            status = statusSnapshot.data ?? 'Needs preparation';
                          }

                          return ManualListCard(
                            title: manual.name,
                            subtitle:
                                'Imported ${_formatDate(manual.importedAt)}',
                            supportingText: status,
                            isDeleting: _deletingManualId == manual.id,
                            onDelete: _deletingManualId == null
                                ? () => _deleteManual(manual)
                                : null,
                            onTap: () => _openManual(manual),
                          );
                        },
                      );
                    },
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
