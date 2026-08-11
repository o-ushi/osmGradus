/// osmWashabeの `TopicCategory`（日常/ビジネス/ランダム）に、同じくosmWashabeが
/// 別モードとして持つ「シチュエーション」を選択肢として統合した4カテゴリ。
enum TopicCategory { daily, business, situational, random }

extension TopicCategoryLabel on TopicCategory {
  String labelKey() => switch (this) {
    TopicCategory.daily => '日常の身近な話題',
    TopicCategory.business => 'ビジネスシーン',
    TopicCategory.situational => 'シチュエーション',
    TopicCategory.random => 'ランダム',
  };

  String get storageKey => switch (this) {
    TopicCategory.daily => 'daily',
    TopicCategory.business => 'business',
    TopicCategory.situational => 'situational',
    TopicCategory.random => 'random',
  };

  static TopicCategory fromStorageKey(String key) =>
      TopicCategory.values.firstWhere(
        (category) => category.storageKey == key,
        orElse: () => throw ArgumentError('Unknown TopicCategory: $key'),
      );
}

/// [TopicService]の「取り込み済みお題」SharedPreferencesキーの接頭辞。
/// [QuestionPromptService]が同じキーを読んで既存データを移行するため、
/// 定数を共有する（`TopicService`↔`QuestionPromptService`の循環importを避ける）。
const String topicsImportedKeyPrefix = 'topics.imported.';
