import '../../../../core/llm/local_llm_service.dart';
import '../../../manuals/data/services/manual_search_service.dart';
import '../../../manuals/domain/models/manual_search_result.dart';
import '../../../manuals/domain/models/saved_manual.dart';
import 'manual_prompt_builder.dart';

class ManualAnswerService {
  ManualAnswerService({
    required ManualSearchService searchService,
    required LocalLlmService llmService,
  }) : _searchService = searchService,
       _llmService = llmService;

  final ManualSearchService _searchService;
  final LocalLlmService _llmService;

  final ManualPromptBuilder _promptBuilder = ManualPromptBuilder();

  Stream<String> answer({
    required SavedManual manual,
    required String question,
    required void Function(List<ManualSearchResult>) onSources,
  }) async* {
    final sources = await _searchService.search(
      manualId: manual.id,
      query: question,
      maxResults: 2,
    );

    onSources(List.unmodifiable(sources));

    if (sources.isEmpty) {
      yield 'No matching passages were found. '
          'Try a more specific question or search term.';
      return;
    }

    if (!_llmService.hasModel) {
      throw StateError(
        'Import and test a model in Settings before asking questions.',
      );
    }

    final prompt = _promptBuilder.build(question: question, sources: sources);

    yield* _llmService.generate(prompt);
  }
}
