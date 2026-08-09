/// 長文読解のキーワード画面で選ぶ、生成条件（JLPTレベル）。
enum LongArticleJlptLevel { n1, n2, n3 }

extension LongArticleJlptLevelStorage on LongArticleJlptLevel {
  /// [LongArticle.generationJlptLevel]に保存するキー。
  String get storageKey => name;

  String get shortLabel => switch (this) {
    LongArticleJlptLevel.n1 => 'N1',
    LongArticleJlptLevel.n2 => 'N2',
    LongArticleJlptLevel.n3 => 'N3',
  };
}

/// 文体の硬さ（雑談ふう〜学術的）。5段階スライダーで選ぶ。
enum LongArticleLooseness { level1, level2, level3, level4, level5 }

extension LongArticleLoosenessValue on LongArticleLooseness {
  /// スライダーの目盛り（1〜5）。
  int get sliderValue => switch (this) {
    LongArticleLooseness.level1 => 1,
    LongArticleLooseness.level2 => 2,
    LongArticleLooseness.level3 => 3,
    LongArticleLooseness.level4 => 4,
    LongArticleLooseness.level5 => 5,
  };
}

/// 生成する文章の目安の長さ。5段階スライダーで選ぶ。
enum LongArticleLength { chars200, chars400, chars600, chars800, chars1000 }

extension LongArticleLengthValue on LongArticleLength {
  /// スライダーの目盛り（1〜5）。
  int get sliderValue => switch (this) {
    LongArticleLength.chars200 => 1,
    LongArticleLength.chars400 => 2,
    LongArticleLength.chars600 => 3,
    LongArticleLength.chars800 => 4,
    LongArticleLength.chars1000 => 5,
  };

  /// 目安の文字数。
  int get targetCharacterCount => switch (this) {
    LongArticleLength.chars200 => 200,
    LongArticleLength.chars400 => 400,
    LongArticleLength.chars600 => 600,
    LongArticleLength.chars800 => 800,
    LongArticleLength.chars1000 => 1000,
  };
}

/// 長文読解のキーワード画面で確定する生成条件一式。
/// [LongArticleAiPrompt.buildPrompt]がプロンプトへ、
/// [LongArticleService.addArticle]の生成メタフィールドへそれぞれ渡す。
class LongArticleGenerationSettings {
  const LongArticleGenerationSettings({
    required this.keyword,
    required this.jlptLevel,
    required this.looseness,
    required this.length,
  });

  final String keyword;
  final LongArticleJlptLevel jlptLevel;
  final LongArticleLooseness looseness;
  final LongArticleLength length;
}
