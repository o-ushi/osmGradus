import 'package:flutter_test/flutter_test.dart';

import 'package:osm_gradus/models/pronunciation_exercise.dart';
import 'package:osm_gradus/models/question_prompt.dart';
import 'package:osm_gradus/models/question_prompt_source.dart';
import 'package:osm_gradus/models/question_prompt_summary_header_scores.dart';
import 'package:osm_gradus/models/topic_category.dart';

QuestionPrompt _prompt({
  int? vocabTestQuestionCount,
  int? vocabTestCorrectCount,
  int? hitScore,
  int? prepScore,
  int? jsstScore,
  Map<PronunciationCategory, int> pronunciationScores = const {},
}) =>
    QuestionPrompt.create(
      field: TopicCategory.daily,
      body: 'ヘッダー換算用',
      source: QuestionPromptSource.manual,
    ).copyWith(
      vocabTestQuestionCount: vocabTestQuestionCount,
      vocabTestCorrectCount: vocabTestCorrectCount,
      hitScore: hitScore,
      prepScore: prepScore,
      jsstScore: jsstScore,
      pronunciationScores: pronunciationScores,
    );

void main() {
  group('vocabAccuracyToFivePoint', () {
    test('0%は1、100%は5。未実施とは区別する', () {
      expect(QuestionPromptSummaryHeaderScores.vocabAccuracyToFivePoint(0), 1);
      expect(QuestionPromptSummaryHeaderScores.vocabAccuracyToFivePoint(1), 5);
    });

    test('percent/20を四捨五入し1〜5にクランプする', () {
      // 10% → 0.5 → 1
      expect(
        QuestionPromptSummaryHeaderScores.vocabAccuracyToFivePoint(0.10),
        1,
      );
      // 20% → 1
      expect(
        QuestionPromptSummaryHeaderScores.vocabAccuracyToFivePoint(0.20),
        1,
      );
      // 30% → 1.5 → 2
      expect(
        QuestionPromptSummaryHeaderScores.vocabAccuracyToFivePoint(0.30),
        2,
      );
      // 50% → 2.5 → 3
      expect(
        QuestionPromptSummaryHeaderScores.vocabAccuracyToFivePoint(0.50),
        3,
      );
      // 75% → 3.75 → 4
      expect(
        QuestionPromptSummaryHeaderScores.vocabAccuracyToFivePoint(0.75),
        4,
      );
      // 90% → 4.5 → 5
      expect(
        QuestionPromptSummaryHeaderScores.vocabAccuracyToFivePoint(0.90),
        5,
      );
    });
  });

  group('jsstCompactBand', () {
    test('接頭辞なし・半角チルダ。ハイフンと全角波ダッシュは使わない', () {
      expect(QuestionPromptSummaryHeaderScores.jsstCompactBand(1), '1~2');
      expect(QuestionPromptSummaryHeaderScores.jsstCompactBand(2), '3~4');
      expect(QuestionPromptSummaryHeaderScores.jsstCompactBand(3), '5~6');
      expect(QuestionPromptSummaryHeaderScores.jsstCompactBand(4), '7~');
      expect(
        QuestionPromptSummaryHeaderScores.jsstCompactBand(3),
        isNot(contains('JSST')),
      );
      expect(
        QuestionPromptSummaryHeaderScores.jsstCompactBand(3),
        isNot(contains('〜')),
      );
      expect(
        QuestionPromptSummaryHeaderScores.jsstCompactBand(3),
        isNot(contains('-')),
      );
      expect(
        QuestionPromptSummaryHeaderScores.jsstCompactBand(null),
        QuestionPromptSummaryHeaderScores.missing,
      );
      expect(
        QuestionPromptSummaryHeaderScores.jsstCompactBand(99),
        QuestionPromptSummaryHeaderScores.missing,
      );
    });
  });

  group('pronunciationMinScore', () {
    test('5カテゴリすべて揃ってから最小値。欠けていればnull', () {
      expect(
        QuestionPromptSummaryHeaderScores.pronunciationMinScore(const {
          PronunciationCategory.tsu: 5,
        }),
        isNull,
      );

      const complete = {
        PronunciationCategory.tsu: 5,
        PronunciationCategory.zRow: 4,
        PronunciationCategory.rRow: 2,
        PronunciationCategory.longVowel: 3,
        PronunciationCategory.sokuon: 4,
      };
      expect(
        QuestionPromptSummaryHeaderScores.pronunciationMinScore(complete),
        2,
      );
    });
  });

  test('labelsは未実施をー、実施済みを換算後の短い値にする', () {
    final empty = _prompt();
    expect(QuestionPromptSummaryHeaderScores.labels(empty), [
      'ー',
      'ー',
      'ー',
      'ー',
      'ー',
    ]);

    final filled = _prompt(
      vocabTestQuestionCount: 4,
      vocabTestCorrectCount: 3,
      hitScore: 5,
      prepScore: 4,
      jsstScore: 3,
      pronunciationScores: const {
        PronunciationCategory.tsu: 5,
        PronunciationCategory.zRow: 4,
        PronunciationCategory.rRow: 4,
        PronunciationCategory.longVowel: 3,
        PronunciationCategory.sokuon: 5,
      },
    );
    expect(QuestionPromptSummaryHeaderScores.labels(filled), [
      '4',
      '5',
      '4',
      '5~6',
      '3',
    ]);
  });
}
