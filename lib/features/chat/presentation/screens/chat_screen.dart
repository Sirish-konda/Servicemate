import 'package:flutter/material.dart';
import 'package:servicemate/features/chat/presentation/screens/manual_answer_history_screen.dart';

import '../../../manuals/data/services/pdf_storage_service.dart';
import '../../../manuals/domain/models/saved_manual.dart';
import '../../../manuals/presentation/widgets/manual_list_card.dart';
import 'ask_manual_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final PdfStorageService _storageService = PdfStorageService();

  late Future<List<SavedManual>> _manualsFuture;

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
      // FutureBuilder displays the loading error.
    }
  }

  void _openManual(SavedManual manual) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => AskManualScreen(manual: manual)),
    );
  }

  void _openHistory(SavedManual manual) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ManualAnswerHistoryScreen(manual: manual),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask a manual'),
        actions: [
          IconButton(
            tooltip: 'Refresh manuals',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<SavedManual>>(
          future: _manualsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Could not load your manuals.'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _reload,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final manuals = snapshot.data ?? [];

            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  Text('Choose a manual', style: textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text(
                    'Ask a question or revisit saved answers '
                    'for a manual on this device.',
                  ),
                  const SizedBox(height: 24),
                  if (manuals.isEmpty)
                    const Text(
                      'No manuals saved yet. Import and prepare '
                      'a PDF from the Manuals tab first.',
                    )
                  else
                    ...manuals.map(
                      (manual) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: ManualListCard(
                                title: manual.name,
                                subtitle: 'Ask a question about this manual',
                                onTap: () => _openManual(manual),
                                supportingText: '',
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Answer history for ${manual.name}',
                              onPressed: () => _openHistory(manual),
                              icon: const Icon(Icons.history),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
