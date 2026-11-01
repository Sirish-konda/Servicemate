enum AnswerReferenceStatus {
  emptyAnswer,
  noSources,
  missingReferences,
  invalidReferences,
  validReferences,
}

class AnswerReferenceValidator {
  const AnswerReferenceValidator();

  AnswerReferenceStatus validate({
    required String answer,
    required int sourceCount,
  }) {
    if (sourceCount < 0) {
      throw ArgumentError.value(
        sourceCount,
        'sourceCount',
        'Must not be negative.',
      );
    }

    if (answer.trim().isEmpty) {
      return AnswerReferenceStatus.emptyAnswer;
    }

    if (sourceCount == 0) {
      return AnswerReferenceStatus.noSources;
    }

    final matches = RegExp(r'\[(\d+)\]').allMatches(answer);

    if (matches.isEmpty) {
      return AnswerReferenceStatus.missingReferences;
    }

    for (final match in matches) {
      final number = int.tryParse(match.group(1)!);

      if (number == null || number < 1 || number > sourceCount) {
        return AnswerReferenceStatus.invalidReferences;
      }
    }

    return AnswerReferenceStatus.validReferences;
  }
}
