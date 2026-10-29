import 'package:flutter/material.dart';

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

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _manualsFuture = _storageService.getSavedManuals();
  }

  void _reloadManuals() {
    setState(() {
      _manualsFuture = _storageService.getSavedManuals();
    });
  }

  Future<void> _openImportScreen() async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const ImportManualScreen()));

    if (!mounted) return;

    _reloadManuals();
  }

  void _openManualDetails(SavedManual manual) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Details for ${manual.name} will be added next.')),
    );
  }

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();

    return '${localDate.day.toString().padLeft(2, '0')}/'
        '${localDate.month.toString().padLeft(2, '0')}/'
        '${localDate.year}';
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

                      return ManualListCard(
                        key: ValueKey(manual.id),
                        title: manual.name,
                        subtitle: 'Imported ${_formatDate(manual.importedAt)}',
                        supportingText: 'Saved locally · Not indexed yet',
                        onTap: () => _openManualDetails(manual),
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
