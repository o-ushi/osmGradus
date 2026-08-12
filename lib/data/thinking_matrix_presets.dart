import '../models/thinking_matrix_column.dart';
import '../models/topic_category.dart';

/// 「25マス思考」カテゴリ別テンプレート（Step 2）。テーマ文字列はl10nキー
/// （日本語ソース）で、[gradus_l10n.dart]にen/viを持つ。
abstract final class ThinkingMatrixPresets {
  /// 日常・ビジネス・オリジナル共通の汎用5列（横軸＝視点）。
  static const generalColumns = <ThinkingMatrixColumn>[
    ThinkingMatrixColumn(id: 'time', labelKey: '時間'),
    ThinkingMatrixColumn(id: 'view', labelKey: '視点'),
    ThinkingMatrixColumn(id: 'compare', labelKey: '比較'),
    ThinkingMatrixColumn(id: 'scale', labelKey: '規模'),
    ThinkingMatrixColumn(id: 'reason', labelKey: '理由'),
  ];

  /// シチュエーション専用3列。
  static const situationColumns = <ThinkingMatrixColumn>[
    ThinkingMatrixColumn(id: 'workplace', labelKey: '職場'),
    ThinkingMatrixColumn(id: 'school', labelKey: '学校'),
    ThinkingMatrixColumn(id: 'hospital', labelKey: '病院'),
  ];

  /// [ThinkingMatrixColumn.id]から[ThinkingMatrixColumn]を引く（JSON復元用）。
  /// 未知のidはnull（呼び出し側で読み飛ばす）。
  static ThinkingMatrixColumn? columnById(String id) {
    for (final column in [...generalColumns, ...situationColumns]) {
      if (column.id == id) return column;
    }
    return null;
  }

  static const dailyThemes = <String>['趣味', '健康', '買い物', '旅行', '季節'];
  static const businessThemes = <String>['時間', 'チーム', '成長', '仕事', '問題'];
  static const situationThemes = <String>['相談', '依頼', '断り', '謝罪', '提案'];

  /// [category]（`daily`/`business`/`situational`のみ）のテーマ名一覧。
  static List<String> themesFor(TopicCategory category) => switch (category) {
    TopicCategory.daily => dailyThemes,
    TopicCategory.business => businessThemes,
    TopicCategory.situational => situationThemes,
    TopicCategory.random => throw ArgumentError(
      'ThinkingMatrixPresets.themesFor()はrandomを取らない',
    ),
  };

  /// [category]の列一覧（シチュエーションだけ3列、他は汎用5列）。
  static List<ThinkingMatrixColumn> columnsFor(TopicCategory category) =>
      switch (category) {
        TopicCategory.situational => situationColumns,
        TopicCategory.daily || TopicCategory.business => generalColumns,
        TopicCategory.random => throw ArgumentError(
          'ThinkingMatrixPresets.columnsFor()はrandomを取らない',
        ),
      };
}
