import 'package:servicemate/features/manuals/data/services/manual_preparation_status_service.dart';
import 'package:servicemate/features/manuals/data/services/pdf_storage_service.dart';
import 'package:servicemate/features/manuals/domain/models/manual_readiness.dart';

import '../../../../core/llm/local_llm_service.dart';
import '../../../manuals/data/services/manual_search_service.dart';
import '../../../manuals/domain/models/manual_search_result.dart';
import '../../../manuals/domain/models/saved_manual.dart';
import 'manual_prompt_builder.dart';

class LocalModelNotInstalledException implements Exception {
  const LocalModelNotInstalledException();
}

class ManualNotReadyException implements Exception {
  const ManualNotReadyException(this.readiness);

  final ManualReadiness readiness;
}



class ManualAnswerService {
  ManualAnswerService({
    required ManualSearchService searchService,
    required LocalLlmService llmService,
  }) : _searchService = searchService,
       _llmService = llmService;

  final ManualSearchService _searchService;
  final LocalLlmService _llmService;

  final ManualPromptBuilder _promptBuilder = ManualPromptBuilder();

  final ManualPreparationStatusService _statusService =
      ManualPreparationStatusService(storageService: PdfStorageService());

  Stream<String> answer({
    required SavedManual manual,
    required String question,
    required void Function(List<ManualSearchResult>) onSources,
  }) async* {
    final ManualReadiness readiness;

    try {
      readiness = await _statusService.getReadiness(manual.id);
    } on FormatException {
      throw const ManualNotReadyException(ManualReadiness.unreadable);
    }

    if (readiness != ManualReadiness.ready) {
      throw ManualNotReadyException(readiness);
    }
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
      throw const LocalModelNotInstalledException();
    }

    final prompt = _promptBuilder.build(question: question, sources: sources);

    yield* _llmService.generate(prompt);
  }
}
