import 'dashboard_summary.dart';

/// 25マス拡充度（`thinking-matrix-expansion-dashboard.md` Step 2）の
/// カテゴリ別％・トータル％・拡充度総合（A〜E）。母数は常に65マス
/// （日常25＋ビジネス25＋シチュエーション15、`ThinkingMatrixService.systemSetIds`
/// の3セットのみ。オリジナル・追加の同カテゴリセットは含めない）。
///
/// 組み立ては[ThinkingMatrixExpansionService.build]（純関数）で行う。
class ThinkingMatrixExpansionSummary {
  const ThinkingMatrixExpansionSummary({
    required this.dailyPercent,
    required this.businessPercent,
    required this.situationalPercent,
    required this.totalPercent,
    required this.expansionGrade,
    required this.weightSum,
    required this.cellCount,
  });

  /// 0.0〜100.0。
  final double dailyPercent;
  final double businessPercent;
  final double situationalPercent;
  final double totalPercent;

  /// 拡充度総合（トータル%基準、Step概要D）。
  final DashboardOverallGrade expansionGrade;

  /// 内訳デバッグ用：65マス全体のウェイト合計（0.0〜65.0）。
  final double weightSum;

  /// 母数（システム3セットが規定どおりなら常に65）。
  final int cellCount;

  static String _displayPercent(double percent) =>
      '${percent.toStringAsFixed(1)}%';

  String get dailyDisplay => _displayPercent(dailyPercent);
  String get businessDisplay => _displayPercent(businessPercent);
  String get situationalDisplay => _displayPercent(situationalPercent);
  String get totalDisplay => _displayPercent(totalPercent);
}
