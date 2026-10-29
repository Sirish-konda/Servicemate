import 'package:flutter/material.dart';

import '../../data/services/manual_search_service.dart';
import '../../data/services/pdf_storage_service.dart';
import '../../domain/models/manual_search_result.dart';
import '../../domain/models/saved_manual.dart';
import '../widgets/manual_search_result_card.dart';
import 'manual_pdf_screen.dart';

class ManualSearchScreen extends StatefulWidget {
  const ManualSearchScreen({super.key, required this.manual});

  final SavedManual manual;

  @override
  State<ManualSearchScreen> createState() => _ManualSearchScreenState();
}

class _ManualSearchScreenState extends State<ManualSearchScreen> {
  final TextEditingController _queryController = TextEditingController();

  late final ManualSearchService _searchService;

  Future<List<ManualSearchResult>>? _resultsFuture;
  String _submittedQuery = '';

  @override
  void initState() {
    super.initState();

    _searchService = ManualSearchService(storageService: PdfStorageService());
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _search() {
    final query = _queryController.text.trim();

    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a word, phrase or error code.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _submittedQuery = query;
      _resultsFuture = _searchService.search(
        manualId: widget.manual.id,
        query: query,
      );
    });
  }

  void _openResult(ManualSearchResult result) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ManualPdfScreen(
          manual: widget.manual,
          initialPageNumber: result.pdfPageNumber,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search manual')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.manual.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _queryController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: 'Question, keywords or error code',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      suffixIcon: IconButton(
                        onPressed: _search,
                        tooltip: 'Search',
                        icon: const Icon(Icons.search),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _resultsFuture == null
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Extract the manual text and create search passages first.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : FutureBuilder<List<ManualSearchResult>>(
                      future: _resultsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          final message =
                              snapshot.error is ManualNotProcessedException
                              ? 'Process this manual before searching.'
                              : 'Could not read the extracted text. '
                                    'Try processing the manual again.';

                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(message, textAlign: TextAlign.center),
                            ),
                          );
                        }

                        final results = snapshot.data ?? [];

                        if (results.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'No matching passages for "$_submittedQuery". '
                                'Try a specific term or error code from the manual.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          itemCount: results.length + 1,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return Text(
                                'Results for "$_submittedQuery"\n'
                                'Showing up to 30 passages ranked by keyword matches.',
                              );
                            }

                            final result = results[index - 1];

                            return ManualSearchResultCard(
                              result: result,
                              onTap: () => _openResult(result),
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
