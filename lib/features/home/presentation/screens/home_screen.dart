import 'package:flutter/material.dart';

import '../../../chat/presentation/screens/ask_manual_screen.dart';
import '../../../manuals/data/services/pdf_storage_service.dart';
import '../../../manuals/domain/models/saved_manual.dart';
import '../../../manuals/presentation/screens/manual_pdf_screen.dart';
import '../widgets/ask_manuals_cards.dart';
import '../widgets/recent_manual_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onTabSelected});

  final ValueChanged<int> onTabSelected;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PdfStorageService _storageService = PdfStorageService();

  late Future<List<SavedManual>> _manualsFuture;
  bool _isSelectingManual = false;

  @override
  void initState() {
    super.initState();
    _manualsFuture = _storageService.getSavedManuals();
  }

  Future<void> _reload() async {
    final future = _storageService.getSavedManuals();

    setState(() {
      _manualsFuture = future;
    });

    try {
      await future;
    } catch (_) {
      // FutureBuilder displays the error.
    }
  }

  void _openPdf(SavedManual manual) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ManualPdfScreen(manual: manual)),
    );
  }

  Future<void> _chooseManual(String question) async {
    if (_isSelectingManual) return;

    _isSelectingManual = true;

    try {
      // Read again so the picker uses the current saved manuals.
      final manuals = await _storageService.getSavedManuals();

      if (!mounted) return;

      if (manuals.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Import and prepare a manual first.')),
        );
        widget.onTabSelected(1);
        return;
      }

      final selected = await showModalBottomSheet<SavedManual>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) {
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(sheetContext).height * 0.6,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Choose a manual',
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: manuals.length,
                      itemBuilder: (_, index) {
                        final manual = manuals[index];

                        return ListTile(
                          leading: const Icon(Icons.picture_as_pdf_outlined),
                          title: Text(manual.name),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.pop(sheetContext, manual);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (!mounted || selected == null) return;

      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              AskManualScreen(manual: selected, initialQuestion: question),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Choosing a manual failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open your manuals.')),
      );
    } finally {
      _isSelectingManual = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Service'),
              TextSpan(
                text: 'Mate',
                style: TextStyle(color: colorScheme.primary),
              ),
            ],
          ),
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () => widget.onTabSelected(3),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Text(
                'What do you need\nhelp with?',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Ask a question about your equipment and find '
                'answers in your manuals.',
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              AskManualsCard(
                onQuestionSubmitted: _chooseManual,
                onTroubleshootPressed: () {
                  _chooseManual('How do I troubleshoot ');
                },
                onProcedurePressed: () {
                  _chooseManual('What are the steps to ');
                },
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Recently imported',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.onTabSelected(1),
                    child: const Text('See all'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<SavedManual>>(
                future: _manualsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const LinearProgressIndicator();
                  }

                  if (snapshot.hasError) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Could not load recent manuals.'),
                        TextButton(
                          onPressed: _reload,
                          child: const Text('Retry'),
                        ),
                      ],
                    );
                  }

                  final manuals = snapshot.data ?? <SavedManual>[];

                  if (manuals.isEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Import your first PDF manual to get started.',
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: () => widget.onTabSelected(1),
                          icon: const Icon(Icons.library_books_outlined),
                          label: const Text('Open manuals'),
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: manuals.take(3).map((manual) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: RecentManualCard(
                          title: manual.name,
                          subtitle: 'Saved on this device',
                          onTap: () => _openPdf(manual),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
