import 'package:shared_preferences/shared_preferences.dart';

/// osmWashabeの `TopicCategory`（日常/ビジネス/ランダム）に、同じくosmWashabeが
/// 別モードとして持つ「シチュエーション」を選択肢として統合した4カテゴリ。
enum TopicCategory { daily, business, situational, random }

extension TopicCategoryLabel on TopicCategory {
  /// 表示名とstorageKeyは同じ日本語文字列を使う。
  String labelKey() => storageKey;

  String get storageKey => switch (this) {
    TopicCategory.daily => '日常',
    TopicCategory.business => 'ビジネス',
    TopicCategory.situational => 'シチュエーション',
    TopicCategory.random => 'ランダム',
  };

  /// Step 1以前の英語storageKey（`daily`等）。旧SharedPreferencesキー・
  /// 旧JSONの読み込み時のみ使う。新規の書き込みでは使わない。
  String get legacyStorageKey => switch (this) {
    TopicCategory.daily => 'daily',
    TopicCategory.business => 'business',
    TopicCategory.situational => 'situational',
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
