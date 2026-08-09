/// ダッシュボードの総合判定グレード。
///
/// JSST・的中度・PREP・語彙・発音の5指標の平均から決める（Step 9）。
/// 5指標すべて1.0〜5.0の範囲を取るため、5指標がすべて揃っていれば平均は
/// 必ず1.0以上になる。E は「平均が低い」ことではなく「5指標のうち1つでも
/// データが無い」ことを表す（旧F・E は廃止し置き換えた）。
enum DashboardOverallGrade { a, b, c, d, e }

extension DashboardOverallGradeLabel on DashboardOverallGrade {
  /// 画面表示用の1文字（A〜E）。
  String get letter => switch (this) {
    DashboardOverallGrade.a => 'A',
    DashboardOverallGrade.b => 'B',
    DashboardOverallGrade.c => 'C',
    DashboardOverallGrade.d => 'D',
    DashboardOverallGrade.e => 'E',
  };
}

/// 直近結果から算出したダッシュボード用の判定サマリー（Step 9: 5指標）。
class DashboardSummary {
  const DashboardSummary({
    required this.overallGrade,
    this.jsstAverageLevel,
    this.hitAverageScore,
    this.prepAverageScore,
    this.vocabularyAverageScore,
    this.pronunciationAverageScore,
    required this.jsstSampleCount,
    this.hitSampleCount = 0,
    this.prepSampleCount = 0,
    required this.vocabularySampleCount,
    required this.pronunciationSampleCount,
    this.averagePoints,
  });

  /// 総合判定（A〜E）。
  final DashboardOverallGrade overallGrade;

  /// 直近JSST結果の平均参考レベル（1.0〜4.0）。該当結果がなければnull。
  /// 表示（[jsstDisplayLabel]）専用で、総合平均には使わない
  /// （総合平均には[DashboardSummaryService]がレベル帯ごとに変換した点数を使う）。
  final double? jsstAverageLevel;

  /// 直近レイヤーⅣ結果の的中度AI評価の平均（1.0〜5.0）。該当結果がなければnull。
  final double? hitAverageScore;

  /// 直近レイヤーⅣ結果のPREP AI評価の平均（1.0〜5.0）。該当結果がなければnull。
  final double? prepAverageScore;

  /// 直近レイヤーⅠ単語テストの平均総合評価（1.0〜5.0）。該当結果がなければnull。
  final double? vocabularyAverageScore;

  /// 直近発音結果の平均スコア（1.0〜5.0）。該当結果がなければnull。
  final double? pronunciationAverageScore;

  /// 平均に使ったJSST結果件数（最大3）。
  final int jsstSampleCount;

  /// 平均に使った的中度AI評価件数（最大3）。
  final int hitSampleCount;

  /// 平均に使ったPREP AI評価件数（最大3）。
  final int prepSampleCount;

  /// 平均に使った単語テスト結果件数（最大3）。
  final int vocabularySampleCount;

  /// 平均に使った発音結果件数（最大3）。
  final int pronunciationSampleCount;

  /// JSST点数・的中度・PREP・語彙・発音の5指標平均（総合ランクの元）。
  /// 5指標のうち1つでもデータが無ければnull（総合はE）。
  final double? averagePoints;

  bool get hasJsst => jsstAverageLevel != null;

  bool get hasHit => hitAverageScore != null;

  bool get hasPrep => prepAverageScore != null;

  bool get hasVocabulary => vocabularyAverageScore != null;

  bool get hasPronunciation => pronunciationAverageScore != null;

  /// 総合表示。「B（3.7）」形式（平均は小数第1位固定）。
  /// 5指標が揃っていない（E）ときは数値の代わりに「ー」を表示する。
  String get overallGradeDisplay {
    final avg = averagePoints;
    final avgText = avg == null ? 'ー' : avg.toStringAsFixed(1);
    return '${overallGrade.letter}（$avgText）';
  }

  /// JSST平均の表示文言。「7〜8」形式（行ラベルが既にJSSTのため接頭辞なし）。
  String get jsstDisplayLabel {
    final level = jsstAverageLevel;
    if (level == null) return 'ー';
    // 参考レベル1〜4をJSST帯の下限・上限へ線形に写像する。
    // 1→1〜2 / 2→3〜4 / 3→5〜6 / 4→7〜8
    final low = 1 + (level - 1) * 2;
    final high = 2 + (level - 1) * 2;
    final lowRounded = low.round().clamp(1, 10);
    final highRounded = high.round().clamp(1, 10);
    if (lowRounded == highRounded) return '$lowRounded';
    return '$lowRounded〜$highRounded';
  }

  /// 的中度・PREP・語彙・発音の共通表示形式（小数第1位、未計測は「ー」）。
  static String _averageDisplay(double? score) =>
      score == null ? 'ー' : score.toStringAsFixed(1);

  String get hitDisplayLabel => _averageDisplay(hitAverageScore);

  String get prepDisplayLabel => _averageDisplay(prepAverageScore);

  String get vocabularyDisplayLabel => _averageDisplay(vocabularyAverageScore);

  String get pronunciationDisplayLabel =>
      _averageDisplay(pronunciationAverageScore);
}
