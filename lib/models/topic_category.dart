import 'package:shared_preferences/shared_preferences.dart';

/// osmWashabeの `TopicCategory`（日常/ビジネス/ランダム）に、同じくosmWashabeが
/// 別モードとして持つ「シチュエーション」を選択肢として統合した4カテゴリ。
///
/// [general]は問題文タブ分類改修（`docs/prompts/question-prompt-tabs.md`）で
/// 追加した5番目の値。[daily]/[business]は問題文側では新規に使わず、
/// 25マス（[ThinkingMatrixSet]）専用のレガシー値として残す
/// （`question-prompt-tabs.md` Step 1〜5では25マス側のプリセットカテゴリを
/// 変更しないため、[TopicCategoryLabel.fromStorageKey]の`日常`/`ビジネス`
/// マッピングもそのまま維持する。問題文の`日常`/`ビジネス`→`general`正規化は
/// Step 2で[QuestionPromptService]側が担う）。
enum TopicCategory { daily, business, situational, general, random }

extension TopicCategoryLabel on TopicCategory {
  /// 表示名のl10nキー。[general]のみstorageKeyと異なるキー
  /// （`問題文カテゴリ_その他`）を使う。既存の`その他`キーは別画面
  /// （ナビの「その他」タブ等）で`More`/`Khác`として使われているため、
  /// 問題文カテゴリの表示（`Situations`と対になる`General`）には流用しない。
  String labelKey() =>
      this == TopicCategory.general ? '問題文カテゴリ_その他' : storageKey;

  String get storageKey => switch (this) {
    TopicCategory.daily => '日常',
    TopicCategory.business => 'ビジネス',
    TopicCategory.situational => 'シチュエーション',
    TopicCategory.general => '一般',
    TopicCategory.random => 'ランダム',
  };

  /// Step 1以前の英語storageKey（`daily`等）。旧SharedPreferencesキー・
  /// 旧JSONの読み込み時のみ使う。新規の書き込みでは使わない。
  String get legacyStorageKey => switch (this) {
    TopicCategory.daily => 'daily',
    TopicCategory.business => 'business',
    TopicCategory.situational => 'situational',
    TopicCategory.general => 'general',
    TopicCategory.random => 'random',
  };

  /// 新storageKey（日本語）を正としつつ、旧英語storageKeyも読める。
  static TopicCategory fromStorageKey(String key) {
    for (final category in TopicCategory.values) {
      if (category.storageKey == key) return category;
    }
    for (final category in TopicCategory.values) {
      if (category.legacyStorageKey == key) return category;
    }
    throw ArgumentError('Unknown TopicCategory: $key');
  }
}

/// 旧`daily`/`business`は`general`にマップする（`question-prompt-tabs.md`
/// Step 4〜6）。問題文の書き込みは`general`のみに揃え、`daily`/`business`は
/// 25マス専用のレガシー値として残す。[TopicCategory.situational]・
/// [TopicCategory.general]・[TopicCategory.random]はそのまま返す。
/// [TopicService]・[QuestionPromptService]の両方から呼ばれるため、循環import
/// を避けてここに一本化する（[loadImportedTopicsPref]と同じ理由）。
TopicCategory normalizeToGeneral(TopicCategory category) =>
    (category == TopicCategory.daily || category == TopicCategory.business)
    ? TopicCategory.general
    : category;

/// [TopicService]の「取り込み済みお題」SharedPreferencesキーの接頭辞。
/// [QuestionPromptService]が同じキーを読んで既存データを移行するため、
/// 定数を共有する（`TopicService`↔`QuestionPromptService`の循環importを避ける）。
const String topicsImportedKeyPrefix = 'topics.imported.';

/// [topicsImportedKeyPrefix]付きキーのカテゴリ別お題リストを読む。新storageKey
/// （日本語）のキーを優先し、無ければ旧英語storageKeyのキーを読んで新キーへ
/// 移し、旧キーを消す（[TopicService]・[QuestionPromptService]の両方から
/// 呼ばれるため、ここに一本化して二重実装を避ける）。
Future<List<String>> loadImportedTopicsPref(
  SharedPreferences prefs,
  TopicCategory category,
) async {
  final newKey = '$topicsImportedKeyPrefix${category.storageKey}';
  final current = prefs.getStringList(newKey);
  if (current != null) return current;

  final legacyKey = '$topicsImportedKeyPrefix${category.legacyStorageKey}';
  final legacy = prefs.getStringList(legacyKey);
  if (legacy == null) return const [];
  await prefs.setStringList(newKey, legacy);
  await prefs.remove(legacyKey);
  return legacy;
}
