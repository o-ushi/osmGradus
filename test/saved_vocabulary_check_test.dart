import 'package:flutter_test/flutter_test.dart';

import 'package:osm_gradus/models/saved_vocabulary_check.dart';
import 'package:osm_gradus/models/vocab_test_session.dart';
import 'package:osm_gradus/models/vocabulary_entry.dart';
import 'package:osm_gradus/models/vocabulary_evaluation.dart';

void main() {
  VocabTestSession session() => VocabTestSession(
    questions: [
      VocabTestQuestion(
        entry: VocabularyEntry(
          id: 'v1',
          word: '観光',
          translation: 'sightseeing',
          createdAt: DateTime(2026, 1, 1),
        ),
        status: VocabTestQuestionStatus.completed,
        sttResult: 'かんこう',
      ),
    ],
  );

  group('SavedVocabularyCheck.fromSession 長文経由', () {
    test('longArticleId/longArticleTitleを保存でき、toJson→fromJsonで復元できる', () {
      final saved = SavedVocabularyCheck.fromSession(
        id: 'chk_1',
        sessionId: 'sess_1',
        createdAt: DateTime(2026, 1, 1),
        session: session(),
        longArticleId: 'la_1',
        longArticleTitle: '旅行',
      );

      expect(saved.longArticleId, 'la_1');
      expect(saved.longArticleTitle, '旅行');
      expect(saved.questionPromptId, isNull);

      final restored = SavedVocabularyCheck.fromJson(saved.toJson());
      expect(restored.longArticleId, 'la_1');
      expect(restored.longArticleTitle, '旅行');
    });

    test('渡さなければnullのまま（問題文経由・通常テストとの後方互換）', () {
      final saved = SavedVocabularyCheck.fromSession(
        id: 'chk_2',
        sessionId: 'sess_2',
        createdAt: DateTime(2026, 1, 1),
        session: session(),
      );

      expect(saved.longArticleId, isNull);
      expect(saved.longArticleTitle, isNull);
      expect(saved.toJson().containsKey('longArticleId'), isFalse);
      expect(saved.toJson().containsKey('longArticleTitle'), isFalse);
    });

    test('comprehensionQuizを保存でき、合成正解数がクイズ1＋単語になる', () {
      final saved = SavedVocabularyCheck.fromSession(
        id: 'chk_quiz',
        sessionId: 'sess_quiz',
        createdAt: DateTime(2026, 1, 1),
        session: session(),
        longArticleId: 'la_1',
        longArticleTitle: '旅行',
        comprehensionQuiz: const SavedComprehensionQuizResult(
          question: '誰と行きましたか？',
          optionA: '友達',
          optionB: '家族',
          correctOption: 'A',
          selectedOption: 'A',
          isCorrect: true,
          explanationJa: '友達とある',
        ),
      );

      expect(saved.comprehensionQuiz, isNotNull);
      expect(saved.combinedQuestionCount, 2);
      expect(saved.combinedCorrectCount, 1);

      final restored = SavedVocabularyCheck.fromJson(saved.toJson());
      expect(restored.comprehensionQuiz!.question, '誰と行きましたか？');
      expect(restored.comprehensionQuiz!.isCorrect, isTrue);
      expect(restored.combinedQuestionCount, 2);
    });

    test('クイズ正解＋単語8/9なら合成は9/10', () {
      final saved = SavedVocabularyCheck.fromSession(
        id: 'chk_9_10',
        sessionId: 'sess',
        createdAt: DateTime(2026, 1, 1),
        session: VocabTestSession(
          questions: [
            for (var i = 0; i < 9; i++)
              VocabTestQuestion(
                entry: VocabularyEntry(
                  id: 'v$i',
                  word: '語$i',
                  translation: 'w$i',
                  createdAt: DateTime(2026, 1, 1),
                ),
                status: VocabTestQuestionStatus.completed,
              ),
          ],
        ),
        evaluation: VocabularyEvaluation(
          overallScore: 4,
          questionEvaluations: [
            for (var i = 0; i < 9; i++)
              VocabularyQuestionEvaluation(correct: i != 8),
          ],
          rawResponse: '{}',
          evaluationVersion: '1',
        ),
        comprehensionQuiz: const SavedComprehensionQuizResult(
          question: 'Q',
          optionA: 'A1',
          optionB: 'B1',
          correctOption: 'A',
          selectedOption: 'A',
          isCorrect: true,
        ),
      );

      expect(saved.evaluation!.correctCount, 8);
      expect(saved.questions, hasLength(9));
      expect(saved.vocabEvaluationOffset, 0);
      expect(saved.combinedCorrectCount, 9);
      expect(saved.combinedQuestionCount, 10);
    });

    test('評価がクイズを1問目に含む新記録は二重計上しない', () {
      final saved = SavedVocabularyCheck.fromSession(
        id: 'chk_aligned',
        sessionId: 'sess',
        createdAt: DateTime(2026, 1, 1),
        session: VocabTestSession(
          questions: [
            for (var i = 0; i < 9; i++)
              VocabTestQuestion(
                entry: VocabularyEntry(
                  id: 'v$i',
                  word: '語$i',
                  translation: 'w$i',
                  createdAt: DateTime(2026, 1, 1),
                ),
                status: VocabTestQuestionStatus.completed,
              ),
          ],
        ),
        evaluation: VocabularyEvaluation(
          overallScore: 4,
          questionEvaluations: [
            const VocabularyQuestionEvaluation(correct: true),
            for (var i = 0; i < 9; i++)
              VocabularyQuestionEvaluation(correct: i != 8),
          ],
          rawResponse: '{}',
          evaluationVersion: '1',
        ),
        comprehensionQuiz: const SavedComprehensionQuizResult(
          question: 'Q',
          optionA: 'A1',
          optionB: 'B1',
          correctOption: 'A',
          selectedOption: 'A',
          isCorrect: true,
        ),
      );

      expect(saved.vocabEvaluationOffset, 1);
      expect(saved.evaluation!.correctCount, 9);
      expect(saved.combinedCorrectCount, 9);
      expect(saved.combinedQuestionCount, 10);
    });

    test('クイズ不正解＋単語9/9なら合成は9/10', () {
      final saved = SavedVocabularyCheck.fromSession(
        id: 'chk_9_10_miss',
        sessionId: 'sess',
        createdAt: DateTime(2026, 1, 1),
        session: VocabTestSession(
          questions: [
            for (var i = 0; i < 9; i++)
              VocabTestQuestion(
                entry: VocabularyEntry(
                  id: 'v$i',
                  word: '語$i',
                  translation: 'w$i',
                  createdAt: DateTime(2026, 1, 1),
                ),
                status: VocabTestQuestionStatus.completed,
              ),
          ],
        ),
        evaluation: const VocabularyEvaluation(
          overallScore: 5,
          questionEvaluations: [
            VocabularyQuestionEvaluation(correct: true),
            VocabularyQuestionEvaluation(correct: true),
            VocabularyQuestionEvaluation(correct: true),
            VocabularyQuestionEvaluation(correct: true),
            VocabularyQuestionEvaluation(correct: true),
            VocabularyQuestionEvaluation(correct: true),
            VocabularyQuestionEvaluation(correct: true),
            VocabularyQuestionEvaluation(correct: true),
            VocabularyQuestionEvaluation(correct: true),
          ],
          rawResponse: '{}',
          evaluationVersion: '1',
        ),
        comprehensionQuiz: const SavedComprehensionQuizResult(
          question: 'Q',
          optionA: 'A1',
          optionB: 'B1',
          correctOption: 'A',
          selectedOption: 'B',
          isCorrect: false,
        ),
      );

      expect(saved.evaluation!.correctCount, 9);
      expect(saved.combinedCorrectCount, 9);
      expect(saved.combinedQuestionCount, 10);
    });

    test('クイズ不正解なら合成正解数は単語分のみ、母数は+1', () {
      final saved = SavedVocabularyCheck(
        id: 'chk_wrong',
        createdAt: DateTime(2026, 1, 1),
        sessionId: 'sess',
        questions: const [
          SavedVocabQuestionResult(
            word: '観光',
            reading: '',
            translation: 'sightseeing',
            status: VocabTestQuestionStatus.completed,
          ),
        ],
        comprehensionQuiz: const SavedComprehensionQuizResult(
          question: 'Q',
          optionA: 'A1',
          optionB: 'B1',
          correctOption: 'A',
          selectedOption: 'B',
          isCorrect: false,
        ),
      );

      expect(saved.combinedQuestionCount, 2);
      expect(saved.combinedCorrectCount, 0);
    });

    test('旧JSON（longArticleId/longArticleTitleキー無し）でも落ちない', () {
      final json = {
        'id': 'chk_3',
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
        'sessionId': 'sess_3',
        'questions': [
          {
            'word': '観光',
            'reading': 'かんこう',
            'translation': 'sightseeing',
            'status': 'completed',
          },
        ],
      };

      final restored = SavedVocabularyCheck.fromJson(json);
      expect(restored.longArticleId, isNull);
      expect(restored.longArticleTitle, isNull);
      expect(restored.comprehensionQuiz, isNull);
      expect(restored.combinedQuestionCount, 1);
    });
  });
}
