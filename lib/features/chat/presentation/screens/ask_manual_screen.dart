import 'package:flutter/material.dart';
import 'package:servicemate/features/chat/data/services/manual_answer_history_service.dart';
import 'package:servicemate/features/chat/presentation/screens/manual_answer_history_screen.dart';

import '../../../../core/llm/local_llm_service.dart';
import '../../../manuals/data/services/manual_search_service.dart';
import '../../../manuals/data/services/pdf_storage_service.dart';
import '../../../manuals/domain/models/manual_search_result.dart';
import '../../../manuals/domain/models/saved_manual.dart';
import '../../../manuals/presentation/screens/manual_pdf_screen.dart';
import '../../data/services/manual_answer_service.dart';

class AskManualScreen extends StatefulWidget {
  const AskManualScreen({super.key, required this.manual});

  final SavedManual manual;

  @override
  State<AskManualScreen> createState() => _AskManualScreenState();
}

class _AskManualScreenState extends State<AskManualScreen> {
  final TextEditingController _questionController = TextEditingController();

  late final ManualAnswerService _answerService;

  bool _isBusy = false;
  bool _failed = false;

  String _answer = '';
  String _status = '';

  List<ManualSearchResult> _sources = [];

  @override
  void initState() {
    super.initState();

    _answerService = ManualAnswerService(
      searchService: ManualSearchService(storageService: PdfStorageService()),
      llmService: LocalLlmService(),
    );
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _saveCompletedAnswer({
    required String question,
    required String answer,
    required List<ManualSearchResult> sources,
  }) async {
    try {
      await _historyService.saveAnswer(
        manualId: widget.manual.id,
        question: question,
        answer: answer,
        sources: sources,
      );

      if (!mounted) return;

      setState(() {
        _historyStatus = 'Saved to answer history.';
      });
    } catch (error, stackTrace) {
      debugPrint('Saving answer history failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _historyStatus =
            'The answer is available, but could not be saved to history.';
      });
    }
  }

  Future<void> _ask() async {
    final question = _questionController.text.trim();

    if (_isBusy || question.isEmpty) return;

    if (question.length > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keep the question within 500 characters.'),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isBusy = true;
      _failed = false;
      _answer = '';
      _sources = [];
      _status = 'Searching the manual...';
      _historyStatus = '';
    });

    final buffer = StringBuffer();

    try {
      await for (final token in _answerService.answer(
        manual: widget.manual,
        question: question,
        onSources: (sources) {
          if (!mounted) return;

          setState(() {
            _sources = sources;
            _status = sources.isEmpty
                ? 'No matching passages.'
                : 'Loading the local model...';
          });
        },
      )) {
        buffer.write(token);

        if (!mounted) continue;

        setState(() {
          _answer = buffer.toString();
          _status = 'Generating answer...';
        });
      }

      if (!mounted) return;

      setState(() {
        _status = _completionMessage();
      });

      if (_answer.trim().isNotEmpty && _sources.isNotEmpty) {
        await _saveCompletedAnswer(
          question: question,
          answer: _answer,
          sources: List<ManualSearchResult>.of(_sources),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Manual answer failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _failed = true;
        _status =
            'Could not complete the answer. Check that the '
            'manual is prepared and the local model test works. '
            'See the debug console for details.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  String _completionMessage() {
    if (_answer.trim().isEmpty) {
      return 'The model returned no answer.';
    }

    if (_sources.isEmpty) {
      return 'Try another search term.';
    }

    final references = RegExp(r'\[(\d+)\]')
        .allMatches(_answer)
        .map((match) => int.parse(match.group(1)!))
        .toList();

    if (references.any((number) => number < 1 || number > _sources.length)) {
      return 'Invalid source references detected. '
          'Treat this answer as unverified.';
    }

    if (references.isEmpty) {
      return 'The answer has no numbered references. '
          'Check it against the retrieved passages.';
    }

    return 'Answer generated. Verify its claims against the sources.';
  }

  void _openSource(ManualSearchResult source) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ManualPdfScreen(
          manual: widget.manual,
          initialPageNumber: source.pdfPageNumber,
        ),
      ),
    );
  }

  void _openHistory() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ManualAnswerHistoryScreen(manual: widget.manual),
      ),
    );
  }

  final ManualAnswerHistoryService _historyService =
      ManualAnswerHistoryService();

  String _historyStatus = '';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: !_isBusy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ask this manual'),
          automaticallyImplyLeading: !_isBusy,
          actions: [
            IconButton(
              tooltip: 'Answer history',
              onPressed: _isBusy ? null : _openHistory,
              icon: const Icon(Icons.history),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(widget.manual.name, style: textTheme.titleMedium),
              const SizedBox(height: 20),
              TextField(
                controller: _questionController,
                enabled: !_isBusy,
                maxLength: 500,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Your question',
                  hintText: 'What is the default fridge temperature?',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _isBusy ? null : _ask,
                child: Text(_isBusy ? 'Working...' : 'Ask manual'),
              ),
              const SizedBox(height: 20),
              if (_isBusy) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
              ],
              if (_status.isNotEmpty) Text(_status),
              if (_historyStatus.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_historyStatus, style: textTheme.bodySmall),
              ],
              if (_answer.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  _failed ? 'Incomplete answer' : 'Answer',
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SelectableText(_answer),
              ],
              if (_sources.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Retrieved sources', style: textTheme.titleMedium),
                const SizedBox(height: 8),
                ..._sources.asMap().entries.map((entry) {
                  final source = entry.value;
                  final number = entry.key + 1;

                  return Card(
                    child: ExpansionTile(
                      title: Text('[$number] PDF page ${source.pdfPageNumber}'),
                      childrenPadding: const EdgeInsets.all(16),
                      children: [
                        SelectableText(source.snippet),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _isBusy ? null : () => _openSource(source),
                          child: const Text('Open PDF page'),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 24),
              const Text(
                'AI-generated text may be incorrect. '
                'Check the original manual before acting.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
