import 'package:flutter/material.dart';
import 'package:servicemate/features/chat/domain/models/saved_manula_answer.dart';

import '../../../manuals/domain/models/saved_manual.dart';
import '../../../manuals/presentation/screens/manual_pdf_screen.dart';
import '../../data/services/manual_answer_history_service.dart';

class ManualAnswerHistoryScreen extends StatefulWidget {
  const ManualAnswerHistoryScreen({super.key, required this.manual});

  final SavedManual manual;

  @override
  State<ManualAnswerHistoryScreen> createState() =>
      _ManualAnswerHistoryScreenState();
}

class _ManualAnswerHistoryScreenState extends State<ManualAnswerHistoryScreen> {
  final ManualAnswerHistoryService _historyService =
      ManualAnswerHistoryService();

  late Future<List<SavedManualAnswer>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _historyService.getAnswers(widget.manual.id);
  }

  void _reload() {
    setState(() {
      _historyFuture = _historyService.getAnswers(widget.manual.id);
    });
  }

  void _openPdf(int pageNumber) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ManualPdfScreen(
          manual: widget.manual,
          initialPageNumber: pageNumber,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Answer history')),
      body: SafeArea(
        child: FutureBuilder<List<SavedManualAnswer>>(
          future: _historyFuture,
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
                      const Text('Could not load answer history.'),
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

            final answers = snapshot.data ?? [];

            if (answers.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No saved answers yet. Ask this manual a question '
                    'to start your history.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: answers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final record = answers[index];

                return SavedAnswerCard(
                  key: ValueKey(record.id),
                  record: record,
                  onOpenPage: _openPdf,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class SavedAnswerCard extends StatelessWidget {
  const SavedAnswerCard({
    super.key,
    required this.record,
    required this.onOpenPage,
  });

  final SavedManualAnswer record;
  final ValueChanged<int> onOpenPage;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final localDate = record.createdAt.toLocal();
    final localizations = MaterialLocalizations.of(context);

    final date = localizations.formatMediumDate(localDate);
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(localDate),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(record.question),
        subtitle: Text('$date · $time'),
        childrenPadding: const EdgeInsets.all(16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Saved answer', style: textTheme.titleSmall),
          const SizedBox(height: 8),
          SelectableText(record.answer),
          const SizedBox(height: 16),
          const Text(
            'This is a saved AI response. Verify its claims '
            'against the original manual.',
          ),
          if (record.sources.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Retrieved sources', style: textTheme.titleSmall),
            const SizedBox(height: 8),
            ...record.sources.asMap().entries.map((entry) {
              final source = entry.value;

              return ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  '[${entry.key + 1}] PDF page ${source.pdfPageNumber}',
                ),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(source.snippet),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => onOpenPage(source.pdfPageNumber),
                    child: const Text('Open PDF page'),
                  ),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }
}
