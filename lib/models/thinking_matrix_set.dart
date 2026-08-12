import 'dart:math';

import '../data/thinking_matrix_presets.dart';
import 'thinking_matrix_cell.dart';
import 'thinking_matrix_cell_status.dart';
import 'thinking_matrix_column.dart';
import 'thinking_theme.dart';
import 'topic_category.dart';

final _idRandom = Random();

/// 「25マス思考」のセット1つ（テーマ5つ×列5つ or 3つ）。
class ThinkingMatrixSet {
  const ThinkingMatrixSet({
    required this.id,
    required this.title,
    this.category,
    required this.columns,
    required this.themes,
    required this.cells,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  final String id;
  final String title;

  /// `daily`/`business`/`situational`のみ。`null`＝オリジナル（テーマを
  /// ユーザーが自分で入力したセット）。`random`は取らない。
  final TopicCategory? category;

  /// このセット自身が持つ列（汎用5列、またはシチュエーション専用3列）。
  final List<ThinkingMatrixColumn> columns;

  /// ちょうど5つ（[ThinkingMatrixSet.create]で保証。[fromJson]は壊れた
  /// バックアップでもそのまま読み込む）。
  final List<ThinkingTheme> themes;

  /// ちょうど[themes]×[columns]（[fromJson]・[ThinkingMatrixSet.create]の
  /// 両方で欠けている組み合わせを空セルで補って埋める）。
  final List<ThinkingMatrixCell> cells;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// 全マスが初めて埋まった瞬間。未コンプリートはnull。一度入ったら、
  /// マスを空に戻して再保存してもこの値は消えない（初回コンプリート日時を
  /// 保持し続ける方針。[copyWith]で明示的に渡さない限り上書きされない）。
  final DateTime? completedAt;

  /// ボードの分母。`themes.length * columns.length`（通常25、シチュエーション
  /// は15）。
  int get totalCells => themes.length * columns.length;

  factory ThinkingMatrixSet.create({
    required String title,
    TopicCategory? category,
    required List<ThinkingTheme> themes,
    required List<ThinkingMatrixColumn> columns,
  }) {
    assert(themes.length == 5, 'ThinkingMatrixSet.create()のthemesはちょうど5つ');
    assert(columns.isNotEmpty, 'ThinkingMatrixSet.create()のcolumnsは空にできない');
    final now = DateTime.now();
    return ThinkingMatrixSet(
      id: 'tm_${now.microsecondsSinceEpoch}_${_idRandom.nextInt(1 << 32)}',
      title: title,
      category: category,
      columns: columns,
      themes: themes,
      cells: _emptyCells(themes, columns, now),
      createdAt: now,
      updatedAt: now,
    );
  }

  ThinkingMatrixSet copyWith({
    String? title,
    List<ThinkingTheme>? themes,
    List<ThinkingMatrixCell>? cells,
    DateTime? updatedAt,
    DateTime? completedAt,
  }) => ThinkingMatrixSet(
    id: id,
    title: title ?? this.title,
    category: category,
    columns: columns,
    themes: themes ?? this.themes,
    cells: cells ?? this.cells,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    completedAt: completedAt ?? this.completedAt,
  );

  int get filledCount =>
      cells.where((c) => c.status != ThinkingMatrixCellStatus.empty).length;

  double get completionRatio => filledCount / totalCells;

  ThinkingMatrixCell cellFor(String themeId, String columnId) =>
      cells.firstWhere(
        (c) => c.themeId == themeId && c.columnId == columnId,
        orElse: () => throw StateError(
          'Cell not found for themeId=$themeId, columnId=$columnId',
        ),
      );

  bool _isFilled(ThinkingMatrixCell cell) =>
      cell.status != ThinkingMatrixCellStatus.empty;

  /// [themeIndex]は[themes]内のインデックス（＝ボードの行）。
  bool isRowFilled(int themeIndex) {
    final themeId = themes[themeIndex].id;
    return columns.every((c) => _isFilled(cellFor(themeId, c.id)));
  }

  bool isColumnFilled(String columnId) =>
      themes.every((t) => _isFilled(cellFor(t.id, columnId)));

  List<String> get completedColumnIds =>
      columns.map((c) => c.id).where(isColumnFilled).toList();

  /// レイヤーⅢのPREP（結論・理由・例示）まで、キーワードと合わせて4項目
  /// すべてtrim後非空か。
  bool isCellPrepComplete(ThinkingMatrixCell cell) =>
      cell.keyword.trim().isNotEmpty &&
      cell.conclusion.trim().isNotEmpty &&
      cell.reason.trim().isNotEmpty &&
      cell.example.trim().isNotEmpty;

  /// レイヤーⅢ「60秒スピーチ」を完了したか。キーワードが空のマスは
  /// （`speech60Done`が壊れたデータでtrueになっていても）falseとして扱う。
  bool isCellSpeech60Done(ThinkingMatrixCell cell) =>
      cell.keyword.trim().isNotEmpty && cell.speech60Done;

  /// 1マスの段階（1〜5、[_ThinkingMatrixCellView]の背景色と対応）。
  /// 1＝未入力、2＝キーワードのみ、3＝PREP（結論・理由・例示）まで完了、
  /// 4＝キーワード＋60秒スピーチ完了（PREP未完了）、
  /// 5＝PREP＋60秒スピーチ完了（最終段階）。
  int cellStage(ThinkingMatrixCell cell) {
    if (!_isFilled(cell)) return 1;
    final prep = isCellPrepComplete(cell);
    final speech = isCellSpeech60Done(cell);
    if (prep && speech) return 5;
    if (speech) return 4;
    if (prep) return 3;
    return 2;
  }

  /// 行・列に属する全マスの中で最も低い[cellStage]。
  int _rowMinStage(int themeIndex) {
    final themeId = themes[themeIndex].id;
    return columns
        .map((c) => cellStage(cellFor(themeId, c.id)))
        .reduce(min);
  }

  int _columnMinStage(String columnId) =>
      themes.map((t) => cellStage(cellFor(t.id, columnId))).reduce(min);

  /// レイヤーⅢの盤面トロフィー段階（0〜4）。行／列の全マスの中で最も低い
  /// [cellStage]を基準に、5で揃うと4つ、4以上で揃うと3つ、3以上で揃うと
  /// 2つ、2以上（全マスキーワードあり）で揃うと1つ、1（未入力を含む）なら0。
  int trophyTierForRow(int themeIndex) =>
      (_rowMinStage(themeIndex) - 1).clamp(0, 4);

  int trophyTierForColumn(String columnId) =>
      (_columnMinStage(columnId) - 1).clamp(0, 4);

  factory ThinkingMatrixSet.fromJson(Map<String, dynamic> json) {
    final themes = _themesFromJson(json['themes'] ?? json['netas']);
    final columns = _columnsFromJson(json['columns']);
    final parsedCells = _cellsFromJson(json['cells']);
    return ThinkingMatrixSet(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      category: _categoryFromJson(json['category']),
      columns: columns,
      themes: themes,
      cells: _normalizedCells(themes, columns, parsedCells),
      createdAt: json['createdAt'] == null
          ? DateTime.now()
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? DateTime.now()
          : DateTime.parse(json['updatedAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (category != null) 'category': category!.storageKey,
    'columns': columns.map((c) => c.id).toList(),
    'themes': themes.map((t) => t.toJson()).toList(),
    'cells': cells.map((c) => c.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
  };

  /// `daily`/`business`/`situational`のみ保存対象。欠落・`random`・旧英語
  /// キー以外の未知の値（`"original"`含む）はすべてオリジナル（`null`）扱い。
  /// 旧英語storageKey（`daily`等）は対応する[TopicCategory]へマップする。
  static TopicCategory? _categoryFromJson(Object? raw) {
    if (raw is! String) return null;
    try {
      final category = TopicCategoryLabel.fromStorageKey(raw);
      return category == TopicCategory.random ? null : category;
    } on ArgumentError {
      return null;
    }
  }

  static List<ThinkingTheme> _themesFromJson(Object? raw) {
    if (raw is! List) return const [];
    final result = <ThinkingTheme>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        result.add(ThinkingTheme.fromJson(Map<String, dynamic>.from(item)));
      } catch (_) {
        continue;
      }
    }
    return result;
  }

  /// 列IDの配列を読む。欠落、または中身が旧5視点（`stance`/`change`を含む）
  /// でも[ThinkingMatrixCell]と同じ変換表を通すため、結果的に汎用5列
  /// （`generalColumns`）へ載せ替わる。未知のIDは読み飛ばし、結果が空なら
  /// `generalColumns`にフォールバックする。
  static List<ThinkingMatrixColumn> _columnsFromJson(Object? raw) {
    if (raw is! List) return ThinkingMatrixPresets.generalColumns;
    final result = <ThinkingMatrixColumn>[];
    for (final item in raw) {
      if (item is! String) continue;
      final column = ThinkingMatrixPresets.columnById(
        ThinkingMatrixCell.migrateColumnId(item),
      );
      if (column != null) result.add(column);
    }
    return result.isEmpty ? ThinkingMatrixPresets.generalColumns : result;
  }

  static List<ThinkingMatrixCell> _cellsFromJson(Object? raw) {
    if (raw is! List) return const [];
    final result = <ThinkingMatrixCell>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        result.add(
          ThinkingMatrixCell.fromJson(Map<String, dynamic>.from(item)),
        );
      } catch (_) {
        continue;
      }
    }
    return result;
  }

  /// [themes]×[columns]の全組み合わせがちょうど1つずつ揃うよう、
  /// [parsedCells]に無い組み合わせは空セルで補う（壊れたバックアップ・
  /// マス不足のデータへの耐性）。[parsedCells]が[columns]に無いIDを
  /// 持っていても、ここでマッチしないため結果的に読み飛ばされる。
  static List<ThinkingMatrixCell> _normalizedCells(
    List<ThinkingTheme> themes,
    List<ThinkingMatrixColumn> columns,
    List<ThinkingMatrixCell> parsedCells,
  ) {
    final now = DateTime.now();
    return [
      for (final theme in themes)
        for (final column in columns)
          parsedCells.firstWhere(
            (c) => c.themeId == theme.id && c.columnId == column.id,
            orElse: () => ThinkingMatrixCell.empty(
              themeId: theme.id,
              columnId: column.id,
              updatedAt: now,
            ),
          ),
    ];
  }

  static List<ThinkingMatrixCell> _emptyCells(
    List<ThinkingTheme> themes,
    List<ThinkingMatrixColumn> columns,
    DateTime now,
  ) => [
    for (final theme in themes)
      for (final column in columns)
        ThinkingMatrixCell.empty(
          themeId: theme.id,
          columnId: column.id,
          updatedAt: now,
        ),
  ];
}
