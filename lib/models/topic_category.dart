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
}
