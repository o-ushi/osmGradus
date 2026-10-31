import '../data/jsst_reference_samples.dart';
import '../models/dashboard_summary.dart';
import '../models/pronunciation_evaluation.dart';
import '../models/saved_pronunciation_check.dart';
import '../models/saved_scoring_result.dart';
import '../models/saved_vocabulary_check.dart';
import '../models/thinking_matrix_set.dart';
import 'jsst_scoring_service.dart';
import 'thinking_matrix_expansion_service.dart';

/// レイヤーⅣ（JSST・的中度・PREP）・Ⅴ（発音）・Ⅰ（単語テスト）の直近結果、
/// および25マス拡充度（Step 2）から、ダッシュボードの3段判定
/// （総合／テスト総合／拡充度総合、Step 3）を組み立てる。
///
/// 入力の[scoringResults]・[pronunciationChecks]は、レイヤーⅣ・Ⅴの
/// 「ランダム」（Ⅳはサイコロ抽選、Ⅴは10問セッション）と「問題文一覧から
/// 選ぶ」のどちらの結果も
/// 区別せず等しく含む（両モードとも同じ[ScoringResultStorage]/
/// [PronunciationCheckStorage]へ保存されるため、ここで両方渡せば自然に
/// 統合される。Step 8）。[QuestionPrompt]エンティティ側のjsstScore/
/// hitScore/prepScore/pronunciationScoresは、これら保存済み結果を問題文
/// 一覧の進捗表示用にミラーしたキャッシュであり、元データそのものは常に
/// [ScoringResultStorage]/[PronunciationCheckStorage]側にあるため、
/// [QuestionPromptService]からは別途読み込まない（読み込むと同じ結果を
/// 二重に平均してしまう）。
abstract final class DashboardSummaryService {
  static const recentLimit = 3;

  /// [scoringResults]・[pronunciationChecks]・[vocabularyChecks]は
  /// いずれも新しい順を想定する。5指標（JSST・的中度・PREP・語彙・発音）を
  /// それぞれ直近有効サンプル最大3件の平均で求め、5指標すべてが揃っている
  /// ときだけその平均でテスト総合A〜Dを決める（1つでも欠けていればE）。
  ///
  /// [thinkingMatrixSets]は[ThinkingMatrixService.loadAll]の全件でよい
  /// （[ThinkingMatrixExpansionService.build]がシステム3セットだけを使う）。
  /// 呼び出し側が先に[ThinkingMatrixService.ensureSystemPresets]しておくこと
  /// を推奨するが、必須ではない（未実施でも欠けたカテゴリは0%として扱われる。
  /// 空リストなら[DashboardSummary.expansion]はnullでなく全0%・拡充度総合Eの
  /// [ThinkingMatrixExpansionSummary]になる）。
  ///
  /// 総合＝テスト総合×拡充度総合を`points(test)+points(expansion)`（0〜8）の
  /// 表で機械的に合成する（概要F）。テスト総合がE（データ不足）でも拡充度が
  /// 進んでいれば総合はE以外になり得る（例: テストE=0点、拡充A=4点→sum=4→C）。
  static DashboardSummary build({
    required List<SavedScoringResult> scoringResults,
    required List<SavedPronunciationCheck> pronunciationChecks,
    List<SavedVocabularyCheck> vocabularyChecks = const [],
    List<ThinkingMatrixSet> thinkingMatrixSets = const [],
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
    final testAveragePoints = hasAllFive
        ? indicatorPoints.cast<double>().reduce((a, b) => a + b) /
              indicatorPoints.length
        : null;
    final testGrade = testAveragePoints == null
        ? DashboardOverallGrade.e
        : gradeFromAverage(testAveragePoints);

    final expansion = ThinkingMatrixExpansionService.build(thinkingMatrixSets);
    final overallGrade = gradeFromCombinedPoints(
      _pointsForGrade(testGrade) + _pointsForGrade(expansion.expansionGrade),
    );

    return DashboardSummary(
      overallGrade: overallGrade,
      testGrade: testGrade,
      expansionGrade: expansion.expansionGrade,
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
      testAveragePoints: testAveragePoints,
      expansion: expansion,
    );
  }

  static double? _average(List<double> values) {
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// 総合の合成表（概要F）用の点数化。A=4, B=3, C=2, D=1, E=0。
  static int _pointsForGrade(DashboardOverallGrade grade) => switch (grade) {
    DashboardOverallGrade.a => 4,
    DashboardOverallGrade.b => 3,
    DashboardOverallGrade.c => 2,
    DashboardOverallGrade.d => 1,
    DashboardOverallGrade.e => 0,
  };

  /// テスト総合・拡充度総合の点数合計（0〜8、[_pointsForGrade]）から
  /// 総合（A〜E）へ（概要F）: A `7〜8` / B `5〜6` / C `3〜4` / D `1〜2` / E `0`。
  static DashboardOverallGrade gradeFromCombinedPoints(int sum) {
    if (sum >= 7) return DashboardOverallGrade.a;
    if (sum >= 5) return DashboardOverallGrade.b;
    if (sum >= 3) return DashboardOverallGrade.c;
    if (sum >= 1) return DashboardOverallGrade.d;
    return DashboardOverallGrade.e;
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
