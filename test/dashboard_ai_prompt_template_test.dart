import 'package:flutter_test/flutter_test.dart';

import 'package:osm_gradus/data/dashboard_ai_prompt_template.dart';
import 'package:osm_gradus/models/pronunciation_evaluation.dart';
import 'package:osm_gradus/models/pronunciation_exercise.dart';
import 'package:osm_gradus/models/saved_pronunciation_check.dart';
import 'package:osm_gradus/models/saved_scoring_result.dart';
import 'package:osm_gradus/models/scoring_models.dart';

SavedScoringResult _scoring({
  String? questionPromptId,
  String? questionPromptBody,
}) {
  final now = DateTime(2026, 1, 1);
  return SavedScoringResult(
    id: 's1',
    createdAt: now,
    result: ScoringResult(
      transcriptChunks: const [],
      fullTranscript: 'テストの回答です。',
      keigo: const KeigoAnalysis(categories: [], varietyScore: 0),
      complexity: const SentenceComplexityAnalysis(
        totalUnits: 1,
        complexUnitCount: 0,
        complexityRatio: 0,
      ),
      fluency: FluencyAnalysis.unavailable(allottedSeconds: 45),
      generatedAt: now,
    ),
    questionPromptId: questionPromptId,
    questionPromptBody: questionPromptBody,
  );
}

SavedPronunciationCheck _pronunciation({
  String? questionPromptId,
  String? questionPromptBody,
}) {
  final now = DateTime(2026, 1, 1);
  return SavedPronunciationCheck(
    id: 'p1',
    createdAt: now,
    transcript: 'テストの回答です。',
    sessionId: 'sess1',
    questions: const [],
    evaluation: PronunciationEvaluation(
      categoryEvaluations: {
        PronunciationCategory.tsu: PronunciationCategoryEvaluation(
          score: 4,
          confidence: PronunciationConfidence.medium,
          feedback: 'ok',
          evidence: 'ev',
        ),
      },
      summary: 'よくできています',
      rawResponse: '{}',
      evaluationVersion: 'v2',
    ),
    source: questionPromptId == null ? 'short' : 'questionPrompt',
    questionPromptId: questionPromptId,
    questionPromptBody: questionPromptBody,
  );
}

void main() {
  group('DashboardAiPromptTemplate（Step 8: 問題文一覧から選ぶ経由の結果も反映）', () {
    test('questionPromptBodyがある採点結果は、対象の問題文をquestionとして含める', () {
      final prompt = DashboardAiPromptTemplate.advicePrompt(
        scoringResults: [
          _scoring(
            questionPromptId: 'qp_1',
            questionPromptBody: '好きな食べ物について話してください',
          ),
        ],
        pronunciationChecks: const [],
        vocabularyChecks: const [],
        lang: 'ja',
      );

      expect(prompt, contains('question: 好きな食べ物について話してください'));
    });

    test('questionPromptBodyが無い（ランダム経由の）採点結果はquestion行を含めない', () {
      final prompt = DashboardAiPromptTemplate.advicePrompt(
        scoringResults: [_scoring()],
        pronunciationChecks: const [],
        vocabularyChecks: const [],
        lang: 'ja',
      );

      expect(prompt, isNot(contains('question:')));
    });

    test('questionPromptBodyがある発音チェック結果も、questionとして含める', () {
      final prompt = DashboardAiPromptTemplate.advicePrompt(
        scoringResults: const [],
        pronunciationChecks: [
          _pronunciation(
            questionPromptId: 'qp_2',
            questionPromptBody: '週末の予定について話してください',
          ),
        ],
        vocabularyChecks: const [],
        lang: 'ja',
      );

      expect(prompt, contains('question: 週末の予定について話してください'));
    });
  });
}
