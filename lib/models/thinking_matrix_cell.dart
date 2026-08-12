import 'thinking_matrix_cell_status.dart';

/// 「25マス思考」の1マス（テーマ×列の組み合わせ1つ）。
class ThinkingMatrixCell {
  const ThinkingMatrixCell({
    required this.themeId,
    required this.columnId,
    this.keyword = '',
    this.status = ThinkingMatrixCellStatus.empty,
    this.conclusion = '',
    this.reason = '',
    this.example = '',
    this.speech60Done = false,
    required this.updatedAt,
  });

  final String themeId;

  /// [ThinkingMatrixColumn.id]。
  final String columnId;

  /// 未入力は空文字。
  final String keyword;
  final ThinkingMatrixCellStatus status;

  /// レイヤーⅢのPREP（結論・理由・例示）。未入力は空文字。レイヤーⅡからは
  /// 触らない。
  final String conclusion;
  final String reason;
  final String example;

  /// レイヤーⅢ「60秒スピーチ」を完了した自己申告。レイヤーⅡからは触らない。
  final bool speech60Done;

  final DateTime updatedAt;

  ThinkingMatrixCell copyWith({
    String? keyword,
    ThinkingMatrixCellStatus? status,
    String? conclusion,
    String? reason,
    String? example,
    bool? speech60Done,
    DateTime? updatedAt,
  }) => ThinkingMatrixCell(
    themeId: themeId,
    columnId: columnId,
    keyword: keyword ?? this.keyword,
    status: status ?? this.status,
    conclusion: conclusion ?? this.conclusion,
    reason: reason ?? this.reason,
    example: example ?? this.example,
    speech60Done: speech60Done ?? this.speech60Done,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  factory ThinkingMatrixCell.empty({
    required String themeId,
    required String columnId,
    required DateTime updatedAt,
  }) => ThinkingMatrixCell(
    themeId: themeId,
    columnId: columnId,
    updatedAt: updatedAt,
  );

  /// 旧`netaId`→[themeId]、旧`perspective`（`time`/`stance`/`compare`/`scale`/
  /// `change`）→[columnId]（`stance`→`view`、`change`→`reason`、他はそのまま）
  /// を読める。新旧どちらのJSONも`columnId`（新）／`perspective`（旧）の
  /// どちらか一方は必ず持つ前提で、両方欠けている壊れたデータは例外にして
  /// 呼び出し側（[ThinkingMatrixSet._cellsFromJson]）で読み飛ばす。
  ///
  /// 旧`status: spoken`（レイヤーⅡの「1分話した」自己申告。廃止済み）は
  /// `filled`に正規化して読む。`conclusion`/`reason`/`example`/
  /// `speech60Done`が無い旧データは既定値（空文字／false）で読む。
  factory ThinkingMatrixCell.fromJson(Map<String, dynamic> json) =>
      ThinkingMatrixCell(
        themeId: (json['themeId'] ?? json['netaId']) as String,
        columnId: migrateColumnId(
          (json['columnId'] ?? json['perspective']) as String,
        ),
        keyword: json['keyword'] as String? ?? '',
        status: _normalizeStatus(
          ThinkingMatrixCellStatusLabel.fromStorageKey(
            json['status'] as String?,
          ),
        ),
        conclusion: json['conclusion'] as String? ?? '',
        reason: json['reason'] as String? ?? '',
        example: json['example'] as String? ?? '',
        speech60Done: json['speech60Done'] as bool? ?? false,
        updatedAt: json['updatedAt'] == null
            ? DateTime.now()
            : DateTime.parse(json['updatedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
    'themeId': themeId,
    'columnId': columnId,
    'keyword': keyword,
    'status': status.storageKey,
    'conclusion': conclusion,
    'reason': reason,
    'example': example,
    'speech60Done': speech60Done,
    'updatedAt': updatedAt.toIso8601String(),
  };

  /// 旧`perspective`のID（`stance`/`change`）を新`columnId`にマップする
  /// （`view`/`reason`）。[ThinkingMatrixSet]の`columns`配列の移行にも使う
  /// ため公開している。
  static String migrateColumnId(String id) => switch (id) {
    'stance' => 'view',
    'change' => 'reason',
    _ => id,
  };

  /// 旧`spoken`（レイヤーⅡのゴールド自己申告。廃止済み）は`filled`に落とす。
  /// 新規の保存では`spoken`を書かない（[ThinkingMatrixCellStatus]は残すが
  /// 新規書き込みでは使わない）。
  static ThinkingMatrixCellStatus _normalizeStatus(
    ThinkingMatrixCellStatus status,
  ) => status == ThinkingMatrixCellStatus.spoken
      ? ThinkingMatrixCellStatus.filled
      : status;
}
