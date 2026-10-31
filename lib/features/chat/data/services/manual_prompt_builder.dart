import '../../../manuals/domain/models/manual_search_result.dart';

class ManualPromptBuilder {
  String build({
    required String question,
    required List<ManualSearchResult> sources,
  }) {
    final passages = sources
        .asMap()
        .entries
        .map((entry) {
          final number = entry.key + 1;
          final source = entry.value;

          return '''
Passage [$number], PDF page ${source.pdfPageNumber}:
${source.snippet}
''';
        })
        .join('\n');

    return '''
Read these reference passages from a manual:

$passages

Question: $question

Answer the question in one short sentence using the passages.
Use the specification for the exact item named in the question.
Include the supporting passage number in square brackets.
If the answer is missing, say you could not find it in the passages.
''';
  }
}
