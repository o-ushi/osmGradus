import 'pronunciation_exercise.dart' show PronunciationCategory;
import 'question_prompt.dart';

/// 総評ヘッダー（Step 9）のⅠ〜Ⅴ点数表示。
///
/// 本文側の詳細（正解率 %、JSST の `JSST 5〜6` など）とは役割を分け、
/// ヘッダーは一目で並ぶ短いラベルだけを返す。換算式はこのクラスに集約する。
abstract final class QuestionPromptSummaryHeaderScores {
  static const missing = 'ー';

  /// Ⅰ〜Ⅴの表示ラベル（未実施は[missing]）。
  static List<String> labels(QuestionPrompt prompt) => [
    layer1(prompt),
    layer2(prompt),
    layer3(prompt),
    layer4(prompt),
    layer5(prompt),
  ];

  /// Ⅰ: 語彙テスト正解率を5点法に換算。未実施は[missing]。
  static String layer1(QuestionPrompt prompt) {
    final accuracy = prompt.vocabTestAccuracy;
    if (accuracy == null) return missing;
    return vocabAccuracyToFivePoint(accuracy).toString();
  }

  /// Ⅱ: 的中度。未実施は[missing]。
  static String layer2(QuestionPrompt prompt) =>
      prompt.hitScore?.toString() ?? missing;

  /// Ⅲ: PREP評点。未実施は[missing]。
  static String layer3(QuestionPrompt prompt) =>
      prompt.prepScore?.toString() ?? missing;

  /// Ⅳ: JSSTバンド（接頭辞なし・半角 `~`）。未実施・不明は[missing]。
  static String layer4(QuestionPrompt prompt) =>
      jsstCompactBand(prompt.jsstScore);

  /// Ⅴ: 「つ」「ざ行」「ラ行」「長音」「促音」がすべて揃っていれば最小値。
  /// 欠けていれば[missing]（記入済みだけでの最小は取らない）。
  static String layer5(QuestionPrompt prompt) {
    final min = pronunciationMinScore(prompt.pronunciationScores);
    return min?.toString() ?? missing;
  }

  /// 正解率 0.0〜1.0 を 1〜5 点に換算する。
  ///
  /// `score = max(1, min(5, (percent / 20).round()))`
  /// ただし `percent = accuracy * 100`。
  /// 実施済みで 0% でも 1（未実施の[missing]とは区別する）。100% は 5。
  static int vocabAccuracyToFivePoint(double accuracy) {
    final percent = (accuracy * 100).clamp(0, 100);
    final raw = (percent / 20).round();
    if (raw < 1) return 1;
    if (raw > 5) return 5;
    return raw;
  }

  /// JSST 内部レベル 1〜4 をヘッダー用の短いバンドにする。
  /// `JsstReferenceSamples.levelLabel` の全角 `〜` と `JSST ` 接頭辞は使わない。
  static String jsstCompactBand(int? level) => switch (level) {
    1 => '1~2',
    2 => '3~4',
    3 => '5~6',
    4 => '7~',
    _ => missing,
  };

  /// 5カテゴリすべてに評点があるときだけ最小値。欠けていれば null。
  static int? pronunciationMinScore(Map<PronunciationCategory, int> scores) {
    if (scores.length < PronunciationCategory.values.length) return null;
    for (final category in PronunciationCategory.values) {
      if (!scores.containsKey(category)) return null;
    }
    return scores.values.reduce((a, b) => a < b ? a : b);
  }
}
