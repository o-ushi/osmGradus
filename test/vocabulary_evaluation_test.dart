import 'package:flutter_test/flutter_test.dart';

import 'package:osm_gradus/models/vocabulary_evaluation.dart';

VocabularyEvaluation _evaluation({
  required int overallScore,
  List<VocabularyQuestionEvaluation> questionEvaluations = const [],
}) => VocabularyEvaluation(
  overallScore: overallScore,
  questionEvaluations: questionEvaluations,
  rawResponse: 'raw',
  evaluationVersion: 'v1',
);

void main() {
  group('VocabularyEvaluation.overallScore クランプ', () {
    test('1〜5の範囲内はそのまま保持される', () {
      expect(_evaluation(overallScore: 1).overallScore, 1);
      expect(_evaluation(overallScore: 3).overallScore, 3);
      expect(_evaluation(overallScore: 5).overallScore, 5);
    });

    test('1未満は1に補正される', () {
      expect(_evaluation(overallScore: 0).overallScore, 1);
      expect(_evaluation(overallScore: -10).overallScore, 1);
    });

    test('5より大きい値は5に補正される', () {
      expect(_evaluation(overallScore: 6).overallScore, 5);
      expect(_evaluation(overallScore: 99).overallScore, 5);
    });
  });

  group('VocabularyEvaluation.starDisplay', () {
    test('スコアに応じた★☆の個数になる', () {
      expect(_evaluation(overallScore: 1).starDisplay, '★☆☆☆☆');
      expect(_evaluation(overallScore: 3).starDisplay, '★★★☆☆');
      expect(_evaluation(overallScore: 5).starDisplay, '★★★★★');
    });
  });

  group('VocabularyEvaluation.correctCount', () {
    test('questionEvaluations中でcorrect:trueの件数を返す', () {
      final evaluation = _evaluation(
        overallScore: 3,
        questionEvaluations: const [
          VocabularyQuestionEvaluation(correct: true),
          VocabularyQuestionEvaluation(correct: false),
          VocabularyQuestionEvaluation(correct: true),
        ],
      );
      expect(evaluation.correctCount, 2);
    });

    test('questionEvaluationsが空なら0', () {
      expect(_evaluation(overallScore: 3).correctCount, 0);
    });
  });

  group('VocabularyEvaluation.fromJson / toJson 往復', () {
    test('toJsonしてfromJsonすると同じ内容に戻る', () {
      final original = VocabularyEvaluation(
        overallScore: 4,
        summary: '総評です。',
        questionEvaluations: const [
          VocabularyQuestionEvaluation(correct: true, feedback: '良い'),
          VocabularyQuestionEvaluation(correct: false),
        ],
        languageCode: 'en',
        rawResponse: 'raw text',
        evaluationVersion: 'v1',
      );

      final restored = VocabularyEvaluation.fromJson(original.toJson());

      expect(restored.overallScore, original.overallScore);
      expect(restored.summary, original.summary);
      expect(restored.questionEvaluations.length, 2);
      expect(restored.questionEvaluations[0].correct, isTrue);
      expect(restored.questionEvaluations[0].feedback, '良い');
      expect(restored.questionEvaluations[1].correct, isFalse);
      expect(restored.questionEvaluations[1].feedback, isNull);
      expect(restored.languageCode, 'en');
      expect(restored.rawResponse, 'raw text');
      expect(restored.evaluationVersion, 'v1');
    });
  });
}
