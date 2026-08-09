import '../data/jsst_reference_samples.dart';
import '../models/dashboard_summary.dart';
import '../models/pronunciation_evaluation.dart';
import '../models/saved_pronunciation_check.dart';
import '../models/saved_scoring_result.dart';
import '../models/saved_vocabulary_check.dart';
import 'jsst_scoring_service.dart';

/// レイヤーⅣ（JSST・的中度・PREP）・Ⅴ（発音）・Ⅰ（単語テスト）の直近結果から
/// ダッシュボード判定を組み立てる（Step 9: 5指標）。
abstract final class DashboardSummaryService {
  static const recentLimit = 3;

  /// [scoringResults]・[pronunciationChecks]・[vocabularyChecks]は
  /// いずれも新しい順を想定する。5指標（JSST・的中度・PREP・語彙・発音）を
  /// それぞれ直近有効サンプル最大3件の平均で求め、5指標すべてが揃っている
  /// ときだけその平均で総合A〜Dを決める。1つでも欠けていればE。
  static DashboardSummary build({
    required List<SavedScoringResult> scoringResults,
    required List<SavedPronunciationCheck> pronunciationChecks,
    List<SavedVocabularyCheck> vocabularyChecks = const [],
  }) {
    final jsstLevels = <double>[];
    final jsstPoints = <double>[];
    for (final saved in scoringResults) {
      if (jsstLevels.length >= recentLimit) break;
      final level = JsstScoringService.combinedReferenceLevel(saved.result);
      if (level == null) continue;
      jsstLevels.add(level.toDouble());
      jsstPoints.add(_jsstPointForLevel(level));
    }

    // 的中度・PREPは同じレイヤーⅣ結果（Chrome AI評価済みのもの）から取るため、
    // 常に同じ件数・同じレコードになる。
    final hitScores = <double>[];
    final prepScores = <double>[];
    for (final saved in scoringResults) {
      if (hitScores.length >= recentLimit) break;
      if (!saved.hasAiEvaluation) continue;
      hitScores.add(saved.hitStars!.toDouble());
      prepScores.add(saved.prepStars!.toDouble());
    }

    final pronunciationScores = <double>[];
    for (final check in pronunciationChecks) {
      if (pronunciationScores.length >= recentLimit) break;
      final score = _sessionAverageScore(check.evaluation);
      if (score == null) continue;
      pronunciationScores.add(score);
    }

    final vocabularyScores = <double>[];
    for (final check in vocabularyChecks) {
      if (vocabularyScores.length >= recentLimit) break;
      final score = check.evaluation?.overallScore;
      if (score == null) continue;
      vocabularyScores.add(score.toDouble());
    }

    final jsstAverageLevel = _average(jsstLevels);
    final jsstAveragePoint = _average(jsstPoints);
    final hitAverage = _average(hitScores);
    final prepAverage = _average(prepScores);
    final vocabularyAverage = _average(vocabularyScores);
    final pronunciationAverage = _average(pronunciationScores);

    final indicatorPoints = [
      jsstAveragePoint,
      hitAverage,
      prepAverage,
      vocabularyAverage,
      pronunciationAverage,
    ];
    final hasAllFive = indicatorPoints.every((p) => p != null);
    final averagePoints = hasAllFive
        ? indicatorPoints.cast<double>().reduce((a, b) => a + b) /
              indicatorPoints.length
        : null;
    final overallGrade = averagePoints == null
        ? DashboardOverallGrade.e
        : gradeFromAverage(averagePoints);

    return DashboardSummary(
      overallGrade: overallGrade,
      jsstAverageLevel: jsstAverageLevel,
      hitAverageScore: hitAverage,
      prepAverageScore: prepAverage,
      vocabularyAverageScore: vocabularyAverage,
      pronunciationAverageScore: pronunciationAverage,
      jsstSampleCount: jsstLevels.length,
      hitSampleCount: hitScores.length,
      prepSampleCount: prepScores.length,
      vocabularySampleCount: vocabularyScores.length,
      pronunciationSampleCount: pronunciationScores.length,
      averagePoints: averagePoints,
    );
  }

  static double? _average(List<double> values) {
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// 5カテゴリの平均（1〜5）。評価が無ければnull。
  static double? _sessionAverageScore(PronunciationEvaluation? evaluation) {
    if (evaluation == null || evaluation.categoryEvaluations.isEmpty) {
      return null;
    }
    final scores = evaluation.categoryEvaluations.values.map((e) => e.score);
    final total = scores.fold<int>(0, (sum, score) => sum + score);
    return total / evaluation.categoryEvaluations.length;
  }

  /// JSST参考レベル（1〜4）→ 総合平均用の点数。
  /// 5.0 ← レベル4（JSST 7〜） / 3.7 ← レベル3（JSST 5〜6） /
  /// 2.3 ← レベル2（JSST 3〜4） / 1.0 ← レベル1（JSST 1〜2）
  static double _jsstPointForLevel(int level) => switch (level) {
    >= 4 => 5.0,
    3 => 3.7,
    2 => 2.3,
    _ => 1.0,
  };

  /// 5指標平均点から総合ランクへ（5指標すべて揃っている前提の値を渡すこと。
  /// 各指標の最小値が1.0のため、この前提下ではaverageが1.0を下回ることはない）。
  /// A: 4.0≦avg / B: 3.0≦avg＜4.0 / C: 2.0≦avg＜3.0 / D: avg＜3.0の残り
  static DashboardOverallGrade gradeFromAverage(double average) {
    if (average >= 4.0) return DashboardOverallGrade.a;
    if (average >= 3.0) return DashboardOverallGrade.b;
    if (average >= 2.0) return DashboardOverallGrade.c;
    return DashboardOverallGrade.d;
  }

  /// プロンプト用に、参考レベルを既存帯ラベルへ変換する。
  static String jsstBandLabel(int? level) =>
      JsstReferenceSamples.levelLabel(level);
}
