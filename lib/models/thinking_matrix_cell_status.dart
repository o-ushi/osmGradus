/// 「25マス思考」1マスの状態。新規の書き込みは`empty`/`filled`のみを使う。
enum ThinkingMatrixCellStatus {
  /// 未入力。
  empty,

  /// キーワードあり。
  filled,

  /// 旧・レイヤーⅡの「1分話した」自己申告（廃止）。読み込み時に`filled`へ
  /// 正規化するための互換用途でのみenum値を残す（[ThinkingMatrixCell.fromJson]
  /// 参照）。新規保存では使わない。
  spoken,
}

extension ThinkingMatrixCellStatusLabel on ThinkingMatrixCellStatus {
  String get storageKey => switch (this) {
    ThinkingMatrixCellStatus.empty => 'empty',
    ThinkingMatrixCellStatus.filled => 'filled',
    ThinkingMatrixCellStatus.spoken => 'spoken',
  };

  /// 不明な値は`empty`にフォールバックする（壊れたバックアップ耐性）。
  static ThinkingMatrixCellStatus fromStorageKey(String? key) =>
      ThinkingMatrixCellStatus.values.firstWhere(
        (status) => status.storageKey == key,
        orElse: () => ThinkingMatrixCellStatus.empty,
      );
}
