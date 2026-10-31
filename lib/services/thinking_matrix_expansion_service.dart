import '../data/thinking_matrix_presets.dart';
import '../models/dashboard_summary.dart';
import '../models/thinking_matrix_cell.dart';
import '../models/thinking_matrix_expansion_summary.dart';
import '../models/thinking_matrix_set.dart';
import '../models/topic_category.dart';
import 'thinking_matrix_service.dart';

/// [ThinkingMatrixExpansionSummary]を組み立てる純関数群。
abstract final class ThinkingMatrixExpansionService {
  /// 1マスのウェイト（0 / 1/3 / 2/3 / 1.0）。段階の最大値を取る（加算しない）。
  /// 内部計算は分数のまま扱い、`0.33`/`0.67`のような丸め誤差を持ち込まない。
  static double cellWeight(ThinkingMatrixSet set, ThinkingMatrixCell cell) {
    if (set.isCellSpeech60Done(cell)) return 1.0;
    if (set.isCellPrepComplete(cell)) return 2 / 3;
    if (cell.keyword.trim().isNotEmpty) return 1 / 3;
    return 0.0;
  }

  /// [allSets]（[ThinkingMatrixService.loadAll]の全件でよい）からシステム3
  /// セット（[ThinkingMatrixService.systemSetIds]）だけを使って集計し、他
  /// （オリジナル・追加の同カテゴリセット）は無視する。欠けているカテゴリ
  /// （[ThinkingMatrixService.ensureSystemPresets]未実施等）は％0とし、
  /// 母数にはそのカテゴリの規定マス数（[ThinkingMatrixPresets]由来）を使う。
  static ThinkingMatrixExpansionSummary build(
    List<ThinkingMatrixSet> allSets,
  ) {
    final byId = {for (final set in allSets) set.id: set};

    double weightSumFor(TopicCategory category) {
      final id = ThinkingMatrixService.systemSetIds[category];
      final set = id == null ? null : byId[id];
      if (set == null) return 0.0;
      return set.cells.fold<double>(
        0.0,
        (sum, cell) => sum + cellWeight(set, cell),
      );
    }

    int cellCountFor(TopicCategory category) =>
        ThinkingMatrixPresets.themesFor(category).length *
        ThinkingMatrixPresets.columnsFor(category).length;

    final dailyCells = cellCountFor(TopicCategory.daily);
    final businessCells = cellCountFor(TopicCategory.business);
    final situationalCells = cellCountFor(TopicCategory.situational);
    final totalCells = dailyCells + businessCells + situationalCells;

    final dailyWeight = weightSumFor(TopicCategory.daily);
    final businessWeight = weightSumFor(TopicCategory.business);
    final situationalWeight = weightSumFor(TopicCategory.situational);
    final weightSum = dailyWeight + businessWeight + situationalWeight;

    final totalPercent = weightSum / totalCells * 100;

    return ThinkingMatrixExpansionSummary(
      dailyPercent: dailyWeight / dailyCells * 100,
      businessPercent: businessWeight / businessCells * 100,
      situationalPercent: situationalWeight / situationalCells * 100,
      totalPercent: totalPercent,
      expansionGrade: gradeForTotalPercent(totalPercent),
      weightSum: weightSum,
      cellCount: totalCells,
    );
  }

  /// 拡充度総合（A〜E）。トータル%基準（Step概要D）:
  /// A `>=75` / B `>=50` / C `>=25` / D `>0` / E `==0`。
  static DashboardOverallGrade gradeForTotalPercent(double totalPercent) {
    if (totalPercent <= 0) return DashboardOverallGrade.e;
    if (totalPercent >= 75) return DashboardOverallGrade.a;
    if (totalPercent >= 50) return DashboardOverallGrade.b;
    if (totalPercent >= 25) return DashboardOverallGrade.c;
    return DashboardOverallGrade.d;
  }
}
