import 'package:flutter_test/flutter_test.dart';
import 'package:osm_gradus/models/dashboard_summary.dart';
import 'package:osm_gradus/models/pronunciation_evaluation.dart';
import 'package:osm_gradus/models/pronunciation_exercise.dart';
import 'package:osm_gradus/models/saved_pronunciation_check.dart';
import 'package:osm_gradus/models/saved_scoring_result.dart';
import 'package:osm_gradus/models/saved_vocabulary_check.dart';
import 'package:osm_gradus/models/scoring_models.dart';
import 'package:osm_gradus/models/vocabulary_evaluation.dart';
import 'package:osm_gradus/services/dashboard_summary_service.dart';
import 'package:osm_gradus/services/jsst_scoring_service.dart';

void main() {
  group('DashboardSummaryService（Step 9: JSST・的中度・PREP・語彙・発音の5指標）', () {
    test('5指標すべて記録なしはE、表示はすべて「ー」', () {
      final summary = DashboardSummaryService.build(
        scoringResults: const [],
        pronunciationChecks: const [],
        vocabularyChecks: const [],
      );
      expect(summary.overallGrade, DashboardOverallGrade.e);
      expect(summary.averagePoints, isNull);
      expect(summary.overallGradeDisplay, 'E（ー）');
      expect(summary.jsstDisplayLabel, 'ー');
      expect(summary.hitDisplayLabel, 'ー');
      expect(summary.prepDisplayLabel, 'ー');
      expect(summary.vocabularyDisplayLabel, 'ー');
      expect(summary.pronunciationDisplayLabel, 'ー');
    });

    test('4指標だけ記録があっても、1指標欠けていればE（データ欠落）', () {
      // JSST・的中度・PREPは1件、発音・語彙は無し → Eのまま。
      final summary = DashboardSummaryService.build(
        scoringResults: [
          _scoringWithAiEval(levelHint: _LevelHint.high, hit: 5, prep: 5),
        ],
        pronunciationChecks: const [],
        vocabularyChecks: const [],
      );
      expect(summary.hasJsst, isTrue);
      expect(summary.hasHit, isTrue);
      expect(summary.hasPrep, isTrue);
      expect(summary.hasPronunciation, isFalse);
      expect(summary.hasVocabulary, isFalse);
      expect(summary.overallGrade, DashboardOverallGrade.e);
      expect(summary.averagePoints, isNull);
    });

    test('5指標すべて満点（JSSTレベル4=5.0点、他4指標も5）でA（4.0以上）', () {
      final summary = DashboardSummaryService.build(
        scoringResults: [
          _scoringWithAiEval(levelHint: _LevelHint.high, hit: 5, prep: 5),
        ],
        pronunciationChecks: [_pronunciation(score: 5)],
        vocabularyChecks: [_vocabulary(score: 5)],
      );
      expect(summary.overallGrade, DashboardOverallGrade.a);
      expect(summary.averagePoints, closeTo(5.0, 0.01));
      expect(summary.overallGradeDisplay, 'A（5.0）');
      expect(summary.hitDisplayLabel, '5.0');
      expect(summary.prepDisplayLabel, '5.0');
      expect(summary.vocabularyDisplayLabel, '5.0');
      expect(summary.pronunciationDisplayLabel, '5.0');
      expect(summary.jsstDisplayLabel, '7〜8');
    });

    test('JSSTレベル→点数の対応: 4→5.0 / 3→3.7 / 2→2.3 / 1→1.0', () {
      for (final (hint, expectedPoint) in [
        (_LevelHint.high, 5.0), // レベル4
        (_LevelHint.midHigh, 3.7), // レベル3
        (_LevelHint.midLow, 2.3), // レベル2
        (_LevelHint.low, 1.0), // レベル1
      ]) {
        final summary = DashboardSummaryService.build(
          scoringResults: [
            _scoringWithAiEval(levelHint: hint, hit: 1, prep: 1),
          ],
          pronunciationChecks: [_pronunciation(score: 1)],
          vocabularyChecks: [_vocabulary(score: 1)],
        );
        // 5指標平均 = (jsstPoint + 1 + 1 + 1 + 1) / 5
        final expectedAverage = (expectedPoint + 1 + 1 + 1 + 1) / 5;
        expect(
          summary.averagePoints,
          closeTo(expectedAverage, 0.01),
          reason: 'levelHint=$hint',
        );
      }
    });

    test('B: 平均が3.0以上4.0未満', () {
      // JSST=3.7, 的中度=4, PREP=4, 語彙=3, 発音=3 → 平均 (3.7+4+4+3+3)/5=3.54 → B
      final summary = DashboardSummaryService.build(
        scoringResults: [
          _scoringWithAiEval(levelHint: _LevelHint.midHigh, hit: 4, prep: 4),
        ],
        pronunciationChecks: [_pronunciation(score: 3)],
        vocabularyChecks: [_vocabulary(score: 3)],
      );
      expect(summary.averagePoints, closeTo(3.54, 0.01));
      expect(summary.overallGrade, DashboardOverallGrade.b);
    });

    test('C: 平均が2.0以上3.0未満', () {
      // JSST=2.3, 的中度=2, PREP=2, 語彙=2, 発音=2 → 平均 2.06 → C
      final summary = DashboardSummaryService.build(
        scoringResults: [
          _scoringWithAiEval(levelHint: _LevelHint.midLow, hit: 2, prep: 2),
        ],
        pronunciationChecks: [_pronunciation(score: 2)],
        vocabularyChecks: [_vocabulary(score: 2)],
      );
      expect(summary.averagePoints, closeTo(2.06, 0.01));
      expect(summary.overallGrade, DashboardOverallGrade.c);
    });

    test('D: 5指標すべて最低値（1.0）のときの平均は1.0でD（5指標が揃っていれば'
        '1.0未満にはならない）', () {
      final summary = DashboardSummaryService.build(
        scoringResults: [
          _scoringWithAiEval(levelHint: _LevelHint.low, hit: 1, prep: 1),
        ],
        pronunciationChecks: [_pronunciation(score: 1)],
        vocabularyChecks: [_vocabulary(score: 1)],
      );
      expect(summary.averagePoints, closeTo(1.0, 0.01));
      expect(summary.overallGrade, DashboardOverallGrade.d);
    });

    test('的中度・PREPはAI評価済みのレイヤーⅣ結果だけを対象にし、直近3件を平均する', () {
      final scoring = [
        _scoringWithAiEval(levelHint: _LevelHint.high, hit: 5, prep: 5),
        _scoring(levelHint: _LevelHint.high), // AI評価なし（対象外）
        _scoringWithAiEval(levelHint: _LevelHint.high, hit: 3, prep: 3),
        _scoringWithAiEval(levelHint: _LevelHint.high, hit: 1, prep: 1),
        _scoringWithAiEval(
          levelHint: _LevelHint.high,
          hit: 5,
          prep: 5,
        ), // 4件目（無視）
      ];
      final summary = DashboardSummaryService.build(
        scoringResults: scoring,
        pronunciationChecks: [_pronunciation(score: 3)],
        vocabularyChecks: [_vocabulary(score: 3)],
      );
      expect(summary.hitSampleCount, 3);
      expect(summary.prepSampleCount, 3);
      expect(summary.hitAverageScore, closeTo((5 + 3 + 1) / 3, 0.01));
      expect(summary.prepAverageScore, closeTo((5 + 3 + 1) / 3, 0.01));
    });

    test('JSST・発音・語彙は直近3件の平均（4件目以降は無視）', () {
      final scoring = [
        _scoringWithAiEval(levelHint: _LevelHint.high, hit: 5, prep: 5), // 4
        _scoringWithAiEval(levelHint: _LevelHint.midHigh, hit: 5, prep: 5), // 3
        _scoringWithAiEval(levelHint: _LevelHint.midLow, hit: 5, prep: 5), // 2
        _scoringWithAiEval(
          levelHint: _LevelHint.low,
          hit: 5,
          prep: 5,
        ), // 無視（4件目）
      ];
      final pronunciation = [
        _pronunciation(score: 5),
        _pronunciation(score: 3),
        _pronunciation(score: 1),
        _pronunciation(score: 5), // 無視
      ];
      final vocabulary = [
        _vocabulary(score: 5),
        _vocabulary(score: 3),
        _vocabulary(score: 1),
        _vocabulary(score: 5), // 無視
      ];
      final summary = DashboardSummaryService.build(
        scoringResults: scoring,
        pronunciationChecks: pronunciation,
        vocabularyChecks: vocabulary,
      );
      expect(summary.jsstSampleCount, 3);
      expect(summary.pronunciationSampleCount, 3);
      expect(summary.vocabularySampleCount, 3);
      expect(summary.jsstAverageLevel, closeTo(3.0, 0.01));
      expect(summary.pronunciationAverageScore, closeTo(3.0, 0.01));
      expect(summary.vocabularyAverageScore, closeTo(3.0, 0.01));
      expect(summary.jsstDisplayLabel, '5〜6');
      expect(summary.pronunciationDisplayLabel, '3.0');
      expect(summary.vocabularyDisplayLabel, '3.0');
    });

    test('評価が未解析（overallScoreなし）の単語テスト結果はスキップされる', () {
      final vocabulary = [
        _vocabulary(score: 4),
        SavedVocabularyCheck(
          id: 'unparsed',
          createdAt: DateTime(2026),
          sessionId: 's',
          questions: const [],
        ),
      ];
      final summary = DashboardSummaryService.build(
        scoringResults: [
          _scoringWithAiEval(levelHint: _LevelHint.high, hit: 4, prep: 4),
        ],
        pronunciationChecks: [_pronunciation(score: 4)],
        vocabularyChecks: vocabulary,
      );
      expect(summary.vocabularySampleCount, 1);
      expect(summary.vocabularyAverageScore, closeTo(4.0, 0.01));
    });

    test('gradeFromAverageの境界（5指標が揃っている前提の値を渡す）', () {
      expect(
        DashboardSummaryService.gradeFromAverage(1),
        DashboardOverallGrade.d,
      );
      expect(
        DashboardSummaryService.gradeFromAverage(2),
        DashboardOverallGrade.c,
      );
      expect(
        DashboardSummaryService.gradeFromAverage(2.99),
        DashboardOverallGrade.c,
      );
      expect(
        DashboardSummaryService.gradeFromAverage(3),
        DashboardOverallGrade.b,
      );
      expect(
        DashboardSummaryService.gradeFromAverage(3.99),
        DashboardOverallGrade.b,
      );
      expect(
        DashboardSummaryService.gradeFromAverage(4),
        DashboardOverallGrade.a,
      );
    });

    test('総合表示は「B（3.5）」のように小数第1位固定で表示される', () {
      // JSST=5.0, 的中度=5, PREP=5, 語彙=5, 発音=1 → 平均 21/5=4.2 → A
      final summary = DashboardSummaryService.build(
        scoringResults: [
          _scoringWithAiEval(levelHint: _LevelHint.high, hit: 5, prep: 5),
        ],
        pronunciationChecks: [_pronunciation(score: 1)],
        vocabularyChecks: [_vocabulary(score: 5)],
      );
      expect(summary.overallGrade, DashboardOverallGrade.a);
      expect(summary.overallGradeDisplay, 'A（4.2）');
    });

    test('「問題文一覧から選ぶ」経由（questionPromptId付き）の結果も、'
        '「ランダム」経由の結果と同じ重みで1件として平均に反映される（Step 8）', () {
      // レイヤーⅣ「問題文一覧から選ぶ」経由の結果は、QuestionPromptService側の
      // jsstScore/hitScore/prepScoreにもミラーされるが、それはStorage側の
      // 結果を問題文一覧の進捗表示用に複製したキャッシュに過ぎない。
      // DashboardSummaryServiceはScoringResultStorage/PronunciationCheckStorage
      // だけを直接の入力とするため、questionPromptId付きの結果を渡しても
      // 二重に数えられず、ちょうど1件として平均される。
      final summary = DashboardSummaryService.build(
        scoringResults: [
          _scoringWithAiEval(
            levelHint: _LevelHint.high,
            hit: 4,
            prep: 4,
            questionPromptId: 'qp_1',
            questionPromptBody: '好きな食べ物について話してください',
          ),
        ],
        pronunciationChecks: [
          _pronunciation(
            score: 3,
            questionPromptId: 'qp_1',
            questionPromptBody: '好きな食べ物について話してください',
          ),
        ],
        vocabularyChecks: [_vocabulary(score: 5)],
      );

      expect(summary.jsstSampleCount, 1);
      expect(summary.hitSampleCount, 1);
      expect(summary.prepSampleCount, 1);
      expect(summary.pronunciationSampleCount, 1);
      expect(summary.hitAverageScore, 4.0);
      expect(summary.prepAverageScore, 4.0);
      expect(summary.pronunciationAverageScore, 3.0);
    });
  });
}

enum _LevelHint { low, midLow, midHigh, high }

/// 参考レベルが出るよう、軸ごとに揃えたダミー採点結果を作る。
SavedScoringResult _scoring({
  required _LevelHint levelHint,
  String? questionPromptId,
  String? questionPromptBody,
}) {
  final (
    keigoVariety,
    complexityRatio,
    fluencyLevel,
    text,
    chunks,
  ) = switch (levelHint) {
    _LevelHint.high => (
      2,
      0.5,
      4,
      '本日はご多忙のところお集まりいただきまして誠にありがとうございます。今後ともよろしくお願い申し上げます。',
      6,
    ),
    _LevelHint.midHigh => (
      0,
      0.2,
      3,
      '今日は天気がいいので公園へ行きました。友達と話をして、カフェでお茶を飲みました。とても楽しかったです。',
      4,
    ),
    _LevelHint.midLow => (
      0,
      0.05,
      2,
      '今日は買い物に行きました。そのあと家でゆっくり休みました。夕方には散歩もしましたよ。',
      3,
    ),
    _LevelHint.low => (0, 0.0, 1, '今日はとてもいい天気ですよ。', 1),
  };

  final started = DateTime(2026, 1, 1, 10);
  final transcriptChunks = [
    for (var i = 0; i < chunks; i++)
      TranscriptChunk(
        text: i == 0 ? text : '。',
        recognizedAt: started.add(Duration(seconds: i * 5)),
      ),
  ];

  final result = ScoringResult(
    transcriptChunks: transcriptChunks,
    fullTranscript: transcriptChunks.map((c) => c.text).join(),
    keigo: KeigoAnalysis(
      varietyScore: keigoVariety,
      categories: [
        KeigoCategoryResult(
          category: 'teineigo',
          matchedExpressions: keigoVariety > 0 ? {'です'} : {},
        ),
        const KeigoCategoryResult(category: 'sonkeigo', matchedExpressions: {}),
        const KeigoCategoryResult(category: 'kenjougo', matchedExpressions: {}),
      ],
    ),
    complexity: SentenceComplexityAnalysis(
      totalUnits: 4,
      complexUnitCount: (4 * complexityRatio).round(),
      complexityRatio: complexityRatio,
    ),
    fluency: FluencyAnalysis(
      allottedSeconds: 45,
      capturedSeconds: 40,
      timeToFirstSpeechSeconds: 1,
      estimatedSpeechSeconds: 30,
      estimatedSilenceSeconds: 10,
      silenceRatio: 0.2,
      timeUtilization: 0.7,
      spokenCharacterCount: text.length,
      charactersPerAllottedMinute: 120,
      longPauseCount: 0,
      referenceLevel: fluencyLevel,
    ),
    session: SpeechSessionContext(
      allottedSeconds: 45,
      startedAt: started,
      endedAt: started.add(const Duration(seconds: 45)),
    ),
  );

  final combined = JsstScoringService.combinedReferenceLevel(result);
  assert(combined != null, 'combined level should be eligible');

  return SavedScoringResult(
    id: 's_${levelHint.name}_${started.microsecondsSinceEpoch}_${_uniqueId++}',
    createdAt: started,
    result: result,
    questionPromptId: questionPromptId,
    questionPromptBody: questionPromptBody,
  );
}

/// PREP・的中度のAI評価も付けた採点結果（Step 8のwithAiEvaluationを使う）。
SavedScoringResult _scoringWithAiEval({
  required _LevelHint levelHint,
  required int hit,
  required int prep,
  String? questionPromptId,
  String? questionPromptBody,
}) {
  return _scoring(
    levelHint: levelHint,
    questionPromptId: questionPromptId,
    questionPromptBody: questionPromptBody,
  ).withAiEvaluation(
    prepStars: prep,
    hitStars: hit,
    prepAdvice: 'prep advice',
    hitAdvice: 'hit advice',
  );
}

int _uniqueId = 0;

SavedPronunciationCheck _pronunciation({
  required int score,
  String? questionPromptId,
  String? questionPromptBody,
}) {
  final now = DateTime(2026, 2, 1);
  final evaluation = PronunciationEvaluation(
    categoryEvaluations: {
      for (final category in PronunciationCategory.values)
        category: PronunciationCategoryEvaluation(
          score: score,
          confidence: PronunciationConfidence.medium,
          feedback: 'ok',
          evidence: 'evidence',
        ),
    },
    summary: 'summary',
    languageCode: 'ja',
    rawResponse: '{}',
    evaluationVersion: 'v2',
  );
  return SavedPronunciationCheck(
    id: 'p_${score}_${_uniqueId++}',
    createdAt: now,
    transcript: '',
    sessionId: 'session',
    questions: const [],
    evaluation: evaluation,
    source: questionPromptId == null ? 'short' : 'questionPrompt',
    questionPromptId: questionPromptId,
    questionPromptBody: questionPromptBody,
  );
}

SavedVocabularyCheck _vocabulary({required int score}) {
  final now = DateTime(2026, 3, 1);
  final evaluation = VocabularyEvaluation(
    overallScore: score,
    questionEvaluations: const [],
    rawResponse: '{}',
    evaluationVersion: 'v1',
  );
  return SavedVocabularyCheck(
    id: 'v_${score}_${_uniqueId++}',
    createdAt: now,
    sessionId: 'session',
    questions: const [],
    evaluation: evaluation,
  );
}
