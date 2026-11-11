import 'package:flutter_test/flutter_test.dart';

import 'package:osm_gradus/models/pronunciation_evaluation.dart';
import 'package:osm_gradus/models/pronunciation_exercise.dart';
import 'package:osm_gradus/services/pronunciation_advice_service.dart';

PronunciationCategoryEvaluation _category({
  int score = 3,
  PronunciationConfidence confidence = PronunciationConfidence.medium,
  String feedbackJa = '概ね良好です。',
  String feedbackVi = 'Khá tốt.',
  String evidence = '期待:「つくえ」/ 認識:「つくえ」',
}) => PronunciationCategoryEvaluation(
  score: score,
  confidence: confidence,
  feedbackJa: feedbackJa,
  feedbackVi: feedbackVi,
  evidence: evidence,
);

PronunciationEvaluation _evaluation(
  Map<PronunciationCategory, PronunciationCategoryEvaluation> categories,
) => PronunciationEvaluation(
  categoryEvaluations: categories,
  summaryJa: '全体的に発音は安定しています。',
  summaryVi: 'Phát âm nhìn chung ổn định.',
  rawResponse: '{"raw":"response"}',
  evaluationVersion: 'v1',
);

void main() {
  group('PronunciationCategoryEvaluation', () {
    test('starDisplayはscoreを★★★★☆形式に変換する', () {
      expect(_category(score: 5).starDisplay, '★★★★★');
      expect(_category(score: 3).starDisplay, '★★★☆☆');
      expect(_category(score: 1).starDisplay, '★☆☆☆☆');
    });

    test('範囲外のscoreは1〜5へ補正される', () {
      expect(_category(score: 0).score, 1);
      expect(_category(score: -10).score, 1);
      expect(_category(score: 6).score, 5);
      expect(_category(score: 999).score, 5);
      expect(_category(score: 0).starDisplay, '★☆☆☆☆');
      expect(_category(score: 999).starDisplay, '★★★★★');
    });

    test('confidenceのJSON往復', () {
      for (final confidence in PronunciationConfidence.values) {
        final original = _category(confidence: confidence);
        final restored = PronunciationCategoryEvaluation.fromJson(
          original.toJson(),
        );
        expect(restored.confidence, confidence);
      }
    });

    test('不明なconfidence文字列はlowにフォールバックする', () {
      final restored = PronunciationCategoryEvaluation.fromJson({
        'score': 4,
        'confidence': 'unknown',
        'feedbackJa': 'ja',
        'feedbackVi': 'vi',
        'evidence': 'evidence',
      });
      expect(restored.confidence, PronunciationConfidence.low);
    });

    test('JSONを往復できる', () {
      final original = _category(
        score: 4,
        confidence: PronunciationConfidence.high,
        feedbackJa: '「つ」の発音は明瞭です。',
        feedbackVi: 'Âm "つ" rất rõ ràng.',
        evidence: '期待:「つくえ」/ 認識:「つくえ」',
      );
      final restored = PronunciationCategoryEvaluation.fromJson(
        original.toJson(),
      );

      expect(restored.score, original.score);
      expect(restored.confidence, original.confidence);
      expect(restored.feedbackJa, original.feedbackJa);
      expect(restored.feedbackVi, original.feedbackVi);
      expect(restored.evidence, original.evidence);
    });
  });

  group('PronunciationEvaluation', () {
    test('JSONを往復できる', () {
      final original = _evaluation({
        PronunciationCategory.tsu: _category(score: 2),
        PronunciationCategory.zRow: _category(score: 4),
        PronunciationCategory.rRow: _category(score: 5),
        PronunciationCategory.longVowel: _category(score: 3),
        PronunciationCategory.sokuon: _category(score: 1),
      });

      final restored = PronunciationEvaluation.fromJson(original.toJson());

      expect(restored.summaryJa, original.summaryJa);
      expect(restored.summaryVi, original.summaryVi);
      expect(restored.rawResponse, original.rawResponse);
      expect(restored.evaluationVersion, original.evaluationVersion);
      expect(
        restored.categoryEvaluations.keys.toSet(),
        original.categoryEvaluations.keys.toSet(),
      );
      for (final category in original.categoryEvaluations.keys) {
        expect(
          restored.categoryEvaluations[category]!.toJson(),
          original.categoryEvaluations[category]!.toJson(),
        );
      }
      expect(restored.toJson(), original.toJson());
    });

    test(
      'displaySummary：新形式（summary）があれば言語指定に関わらずそれを優先する',
      () {
        final evaluation = PronunciationEvaluation(
          categoryEvaluations: const {},
          summary: 'Single language summary.',
          summaryJa: '旧形式の日本語講評（使われないはず）',
          summaryVi: '旧形式のベトナム語講評（使われないはず）',
          rawResponse: '{}',
          evaluationVersion: 'v2',
        );

        expect(evaluation.displaySummary('ja'), 'Single language summary.');
        expect(evaluation.displaySummary('vi'), 'Single language summary.');
        expect(evaluation.displaySummary('en'), 'Single language summary.');
      },
    );

    test(
      'displaySummary：旧形式（summaryなし）はlanguageCodeに応じてsummaryJa/summaryViから選ぶ',
      () {
        final evaluation = PronunciationEvaluation(
          categoryEvaluations: const {},
          summaryJa: '日本語の講評',
          summaryVi: 'Bản tóm tắt tiếng Việt',
          rawResponse: '{}',
          evaluationVersion: 'v1',
        );

        expect(evaluation.displaySummary('vi'), 'Bản tóm tắt tiếng Việt');
        // 'en'はv1に対応する専用フィールドがないため、日本語にフォールバックする。
        expect(evaluation.displaySummary('en'), '日本語の講評');
        expect(evaluation.displaySummary('ja'), '日本語の講評');
      },
    );

    test('languageCodeは省略時は既定で"ja"になり、JSONに保存・復元される', () {
      final withoutLang = PronunciationEvaluation(
        categoryEvaluations: const {},
        summary: 's',
        rawResponse: '{}',
        evaluationVersion: 'v2',
      );
      expect(withoutLang.languageCode, 'ja');

      final withLang = PronunciationEvaluation(
        categoryEvaluations: const {},
        summary: 's',
        languageCode: 'en',
        rawResponse: '{}',
        evaluationVersion: 'v2',
      );
      final restored = PronunciationEvaluation.fromJson(withLang.toJson());
      expect(restored.languageCode, 'en');
    });
  });

  group('PronunciationCategoryEvaluation 新形式（feedback）', () {
    test('feedbackが設定されていれば、旧形式のfeedbackJa/feedbackViはnullのままJSON往復できる', () {
      final original = PronunciationCategoryEvaluation(
        score: 4,
        confidence: PronunciationConfidence.high,
        feedback: 'Single language feedback.',
        evidence: 'evidence text',
      );

      expect(original.feedbackJa, isNull);
      expect(original.feedbackVi, isNull);

      final restored = PronunciationCategoryEvaluation.fromJson(
        original.toJson(),
      );
      expect(restored.feedback, 'Single language feedback.');
      expect(restored.feedbackJa, isNull);
      expect(restored.feedbackVi, isNull);
    });
  });

  group('PronunciationAdviceService', () {
    const service = PronunciationAdviceService();

    test('最もスコアが低い2カテゴリを選ぶ', () {
      final evaluation = _evaluation({
        PronunciationCategory.tsu: _category(score: 1),
        PronunciationCategory.zRow: _category(score: 5),
        PronunciationCategory.rRow: _category(score: 2),
        PronunciationCategory.longVowel: _category(score: 4),
        PronunciationCategory.sokuon: _category(score: 3),
      });

      final lowest = service.lowestScoringCategories(evaluation);

      expect(lowest, [PronunciationCategory.tsu, PronunciationCategory.rRow]);
    });

    test('同点の場合はカテゴリの宣言順で安定して選ばれる（Mapの格納順に依存しない）', () {
      // sokuonから先に格納しても、宣言順(tsu, zRow, rRow, longVowel, sokuon)の
      // うち最初にタイになったカテゴリが優先されること。
      final evaluation = _evaluation({
        PronunciationCategory.sokuon: _category(score: 2),
        PronunciationCategory.longVowel: _category(score: 2),
        PronunciationCategory.rRow: _category(score: 5),
        PronunciationCategory.zRow: _category(score: 2),
        PronunciationCategory.tsu: _category(score: 4),
      });

      final lowest = service.lowestScoringCategories(evaluation);

      expect(lowest, [
        PronunciationCategory.zRow,
        PronunciationCategory.longVowel,
      ]);
    });

    test('全カテゴリ同点でも常に同じ2件が選ばれる', () {
      final evaluation = _evaluation({
        for (final category in PronunciationCategory.values)
          category: _category(score: 3),
      });

      final lowest1 = service.lowestScoringCategories(evaluation);
      final lowest2 = service.lowestScoringCategories(evaluation);

      expect(lowest1, [PronunciationCategory.tsu, PronunciationCategory.zRow]);
      expect(lowest1, lowest2);
    });

    test('maxCategoriesで件数を制御できる', () {
      final evaluation = _evaluation({
        PronunciationCategory.tsu: _category(score: 1),
        PronunciationCategory.zRow: _category(score: 2),
        PronunciationCategory.rRow: _category(score: 3),
      });

      expect(
        service.lowestScoringCategories(evaluation, maxCategories: 1),
        [PronunciationCategory.tsu],
      );
    });

    test('カテゴリが1件のみの場合はそのカテゴリだけで文を作る', () {
      final evaluation = _evaluation({
        PronunciationCategory.tsu: _category(score: 1),
      });

      expect(
        service.buildAdvice(evaluation),
        'あなたは「つ」を練習すると、日本人への伝わり方が大きく改善します。',
      );
    });

    test('カテゴリが0件の場合は空文字を返す', () {
      final evaluation = _evaluation({});
      expect(service.buildAdvice(evaluation), '');
    });

    test('最低2カテゴリに言及するアドバイス文を作る', () {
      final evaluation = _evaluation({
        PronunciationCategory.tsu: _category(score: 1),
        PronunciationCategory.zRow: _category(score: 5),
        PronunciationCategory.rRow: _category(score: 2),
        PronunciationCategory.longVowel: _category(score: 4),
        PronunciationCategory.sokuon: _category(score: 3),
      });

      expect(
        service.buildAdvice(evaluation),
        'あなたは「つ」と「ら行」を練習すると、日本人への伝わり方が大きく改善します。',
      );
    });
  });

  group('PronunciationEvaluation.overallEvaluations', () {
    test('総合観点（rhythm/omission）はJSON往復で保持される', () {
      final original = PronunciationEvaluation(
        categoryEvaluations: {PronunciationCategory.tsu: _category()},
        overallEvaluations: {
          PronunciationOverallAspect.rhythm: _category(score: 2),
          PronunciationOverallAspect.omission: _category(score: 4),
        },
        rawResponse: '{}',
        evaluationVersion: 'v2',
      );
      final restored = PronunciationEvaluation.fromJson(original.toJson());
      expect(
        restored.overallEvaluations[PronunciationOverallAspect.rhythm]?.score,
        2,
      );
      expect(
        restored.overallEvaluations[PronunciationOverallAspect.omission]?.score,
        4,
      );
    });

    test('旧データ（overallEvaluationsなし）は空として読み込む', () {
      final json = _evaluation({
        PronunciationCategory.tsu: _category(),
      }).toJson();
      expect(json.containsKey('overallEvaluations'), isFalse);
      final restored = PronunciationEvaluation.fromJson(json);
      expect(restored.overallEvaluations, isEmpty);
      expect(restored.categoryEvaluations, hasLength(1));
    });

    test('未知のキーや崩れた要素は捨て、評価全体は失敗させない', () {
      final restored = PronunciationEvaluation.fromJson({
        'categoryEvaluations': {
          'tsu': _category().toJson(),
        },
        'overallEvaluations': {
          'rhythm': {'score': 3, 'confidence': 'low', 'evidence': '区切れ'},
          'omission': {'score': 'bad'},
          'unknown': {'score': 5, 'confidence': 'high', 'evidence': 'x'},
        },
        'rawResponse': '{}',
        'evaluationVersion': 'v2',
      });
      expect(restored.overallEvaluations.keys, [
        PronunciationOverallAspect.rhythm,
      ]);
      expect(restored.categoryEvaluations, hasLength(1));
    });
  });
}
