import '../../../manuals/domain/models/manual_search_result.dart';

class SavedManualAnswer {
  SavedManualAnswer({
    required this.id,
    required this.manualId,
    required this.question,
    required this.answer,
    required this.createdAt,
    required List<ManualSearchResult> sources,
  }) : sources = List.unmodifiable(sources);

  final String id;
  final String manualId;
  final String question;
  final String answer;
  final DateTime createdAt;
  final List<ManualSearchResult> sources;

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': 1,
      'id': id,
      'manualId': manualId,
      'question': question,
      'answer': answer,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'sources': sources.map((source) {
        return {
          'pdfPageNumber': source.pdfPageNumber,
          'snippet': source.snippet,
        };
      }).toList(),
    };
  }

  factory SavedManualAnswer.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported answer history version.');
    }

    final rawSources = json['sources'];

    if (rawSources is! List) {
      throw const FormatException('Invalid answer sources.');
    }

    final sources = rawSources.map((value) {
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Invalid answer source.');
      }

      final page = value['pdfPageNumber'];
      final snippet = value['snippet'];

      if (page is! int || page < 1 || snippet is! String) {
        throw const FormatException('Invalid answer source fields.');
      }

      return ManualSearchResult(pdfPageNumber: page, snippet: snippet);
    }).toList();

    return SavedManualAnswer(
      id: _readString(json, 'id'),
      manualId: _readString(json, 'manualId'),
      question: _readString(json, 'question'),
      answer: _readString(json, 'answer'),
      createdAt: DateTime.parse(_readString(json, 'createdAt')),
      sources: sources,
    );
  }

  static String _readString(Map<String, dynamic> json, String key) {
    final value = json[key];

    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Invalid or missing "$key".');
    }

    return value;
  }
}
