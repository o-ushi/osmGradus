/// 「25マス思考」の列1つ（横軸）。汎用5列（時間/視点/比較/規模/理由）と、
/// シチュエーション専用3列（職場/学校/病院）の両方をこの型で表す。
class ThinkingMatrixColumn {
  const ThinkingMatrixColumn({required this.id, required this.labelKey});

  /// [ThinkingMatrixCell.columnId]・保存JSONの`columns`と対応するID。
  final String id;

  /// 列見出し・セルシート見出しに使うl10nキー（日本語ソース）。
  final String labelKey;
}
