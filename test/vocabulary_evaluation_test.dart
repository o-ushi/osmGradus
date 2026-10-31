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

  group('VocabularyEvaluation.aligningComprehensionQuiz', () {
    test('単語だけの9件なら先頭にクイズを付け足して10件になり★は正解率から出す', () {
      final aligned = _evaluation(
        overallScore: 4,
        questionEvaluations: [
          for (var i = 0; i < 9; i++)
            VocabularyQuestionEvaluation(correct: i != 8),
        ],
      ).aligningComprehensionQuiz(isCorrect: true, vocabQuestionCount: 9);

      expect(aligned.questionEvaluations, hasLength(10));
      expect(aligned.questionEvaluations.first.correct, isTrue);
      expect(aligned.correctCount, 9);
      expect(aligned.overallScore, 5);
    });

    test('クイズ不正解なら正解率に応じて★が下がる', () {
      final aligned = _evaluation(
        overallScore: 5,
        questionEvaluations: [
          for (var i = 0; i < 9; i++)
            VocabularyQuestionEvaluation(correct: i != 8),
        ],
      ).aligningComprehensionQuiz(isCorrect: false, vocabQuestionCount: 9);

      expect(aligned.correctCount, 8);
      expect(aligned.overallScore, 4);
    });

    test('既に10件なら先頭の正誤を機械採点で上書きする', () {
      final aligned = _evaluation(
        overallScore: 5,
        questionEvaluations: [
          const VocabularyQuestionEvaluation(correct: false, feedback: 'ai'),
          for (var i = 0; i < 9; i++)
            const VocabularyQuestionEvaluation(correct: true),
        ],
      ).aligningComprehensionQuiz(isCorrect: true, vocabQuestionCount: 9);

      expect(aligned.questionEvaluations, hasLength(10));
      expect(aligned.questionEvaluations.first.correct, isTrue);
      expect(aligned.questionEvaluations.first.feedback, 'ai');
      expect(aligned.correctCount, 10);
      expect(aligned.overallScore, 5);
    });
  });

  group('VocabularyEvaluation.starsFromCorrectRatio', () {
    test('8/10は★4、0件は★1', () {
      expect(
        VocabularyEvaluation.starsFromCorrectRatio([
          for (var i = 0; i < 8; i++)
            const VocabularyQuestionEvaluation(correct: true),
          const VocabularyQuestionEvaluation(correct: false),
          const VocabularyQuestionEvaluation(correct: false),
        ]),
        4,
      );
      expect(VocabularyEvaluation.starsFromCorrectRatio(const []), 1);
    });
  });
}
