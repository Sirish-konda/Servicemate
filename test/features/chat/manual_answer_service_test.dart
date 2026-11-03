import 'package:flutter_test/flutter_test.dart';
import 'package:servicemate/core/llm/local_llm_service.dart';
import 'package:servicemate/features/chat/data/services/manual_answer_service.dart';
import 'package:servicemate/features/manuals/data/services/manual_preparation_status_service.dart';
import 'package:servicemate/features/manuals/data/services/manual_search_service.dart';
import 'package:servicemate/features/manuals/data/services/pdf_storage_service.dart';
import 'package:servicemate/features/manuals/domain/models/manual_readiness.dart';
import 'package:servicemate/features/manuals/domain/models/manual_search_result.dart';
import 'package:servicemate/features/manuals/domain/models/saved_manual.dart';

class FakeStatusService extends ManualPreparationStatusService {
  FakeStatusService() : super(storageService: PdfStorageService());

  ManualReadiness readiness = ManualReadiness.ready;
  bool throwFormatError = false;

  @override
  Future<ManualReadiness> getReadiness(String manualId) async {
    if (throwFormatError) {
      throw const FormatException('Damaged preparation data.');
    }

    return readiness;
  }
}

class FakeSearchService extends ManualSearchService {
  FakeSearchService() : super(storageService: PdfStorageService());

  int calls = 0;
  int? requestedLimit;
  List<ManualSearchResult> results = [];

  @override
  Future<List<ManualSearchResult>> search({
    required String manualId,
    required String query,
    int maxResults = 30,
  }) async {
    calls++;
    requestedLimit = maxResults;
    return results;
  }
}

class FakeLlmService extends LocalLlmService {
  bool installed = true;
  int generationCalls = 0;
  String? receivedPrompt;

  @override
  bool get hasModel => installed;

  @override
  Stream<String> generate(String prompt) async* {
    generationCalls++;
    receivedPrompt = prompt;

    yield 'The default is ';
    yield '3 °C [1].';
  }
}

void main() {
  final manual = SavedManual(
    id: '11111111-1111-4111-8111-111111111111',
    name: 'Test manual.pdf',
    sizeBytes: 100,
    importedAt: DateTime.utc(2026, 1, 1),
  );

  late FakeStatusService status;
  late FakeSearchService search;
  late FakeLlmService llm;
  late ManualAnswerService service;

  setUp(() {
    status = FakeStatusService();
    search = FakeSearchService();
    llm = FakeLlmService();

    service = ManualAnswerService(
      searchService: search,
      llmService: llm,
      statusService: status,
    );
  });

  Stream<String> ask({void Function(List<ManualSearchResult>)? onSources}) {
    return service.answer(
      manual: manual,
      question: 'What is the default fridge temperature?',
      onSources: onSources ?? (_) {},
    );
  }

  for (final readiness in ManualReadiness.values) {
    if (readiness == ManualReadiness.ready) continue;

    test('${readiness.name} blocks search and inference', () async {
      status.readiness = readiness;

      await expectLater(
        ask().toList(),
        throwsA(
          isA<ManualNotReadyException>().having(
            (error) => error.readiness,
            'readiness',
            readiness,
          ),
        ),
      );

      expect(search.calls, 0);
      expect(llm.generationCalls, 0);
    });
  }

  test('damaged readiness data becomes an unreadable error', () async {
    status.throwFormatError = true;

    await expectLater(
      ask().toList(),
      throwsA(
        isA<ManualNotReadyException>().having(
          (error) => error.readiness,
          'readiness',
          ManualReadiness.unreadable,
        ),
      ),
    );

    expect(search.calls, 0);
    expect(llm.generationCalls, 0);
  });

  test('no matching passages returns a message without inference', () async {
    List<ManualSearchResult>? receivedSources;

    final tokens = await ask(onSources: (sources) => receivedSources = sources)
        .toList();

    expect(tokens.join(), contains('No matching passages'));
    expect(receivedSources, isEmpty);
    expect(search.calls, 1);
    expect(llm.generationCalls, 0);
  });

  test('matching passages require an installed model', () async {
    search.results = [
      ManualSearchResult(
        pdfPageNumber: 28,
        snippet: 'The default fridge temperature is 3 °C.',
      ),
    ];
    llm.installed = false;

    await expectLater(
      ask().toList(),
      throwsA(isA<LocalModelNotInstalledException>()),
    );

    expect(llm.generationCalls, 0);
  });

  test(
    'ready manual passes evidence to the model and streams output',
    () async {
      const evidence = 'The default fridge temperature is 3 °C.';

      search.results = [
        ManualSearchResult(pdfPageNumber: 28, snippet: evidence),
      ];

      List<ManualSearchResult>? receivedSources;

      final tokens = await ask(
        onSources: (sources) => receivedSources = sources,
      ).toList();

      expect(tokens, ['The default is ', '3 °C [1].']);
      expect(search.requestedLimit, 2);
      expect(llm.generationCalls, 1);
      expect(llm.receivedPrompt, contains(evidence));
      expect(
        llm.receivedPrompt,
        contains('What is the default fridge temperature?'),
      );
      expect(receivedSources!.single.pdfPageNumber, 28);
      expect(() => receivedSources!.clear(), throwsUnsupportedError);
    },
  );
}
