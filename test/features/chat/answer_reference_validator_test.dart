import 'package:flutter_test/flutter_test.dart';
import 'package:servicemate/features/chat/data/services/answer_reference_validator.dart';

void main() {
  const validator = AnswerReferenceValidator();

  test('detects an empty answer', () {
    expect(
      validator.validate(answer: '  ', sourceCount: 1),
      AnswerReferenceStatus.emptyAnswer,
    );
  });

  test('detects an answer without retrieved sources', () {
    expect(
      validator.validate(answer: 'Some answer.', sourceCount: 0),
      AnswerReferenceStatus.noSources,
    );
  });

  test('detects missing numbered references', () {
    expect(
      validator.validate(answer: 'The setting is 3 °C.', sourceCount: 1),
      AnswerReferenceStatus.missingReferences,
    );
  });

  test('rejects page numbers used as unavailable source references', () {
    expect(
      validator.validate(answer: 'The setting is 3 °C [28].', sourceCount: 2),
      AnswerReferenceStatus.invalidReferences,
    );
  });

  test('rejects zero as a source reference', () {
    expect(
      validator.validate(answer: 'Some answer [0].', sourceCount: 2),
      AnswerReferenceStatus.invalidReferences,
    );
  });

  test('accepts references within the source range', () {
    expect(
      validator.validate(
        answer: 'First claim [1]. Second claim [2].',
        sourceCount: 2,
      ),
      AnswerReferenceStatus.validReferences,
    );
  });

  test('valid reference numbers do not establish factual accuracy', () {
    expect(
      validator.validate(answer: 'An unsupported claim [1].', sourceCount: 1),
      AnswerReferenceStatus.validReferences,
    );
  });
}
