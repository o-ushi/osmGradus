import '../models/long_article_generation_settings.dart';
import 'google_ai_search.dart';

/// 長文読解のキーワード画面で選んだ条件から、Chrome AIに1本の日本語読み物を
/// 生成させるプロンプト。[VocabularyAiImportPrompt]と同じく、生成言語は
/// 常に日本語固定（[GoogleAiSearch.withJapanesePrefix]）。
abstract final class LongArticleAiPrompt {
  LongArticleAiPrompt._();

  static String _jlptDescription(LongArticleJlptLevel level) => switch (level) {
    LongArticleJlptLevel.n1 => 'JLPT N1相当（上級）の語彙・文法を中心に使う、やや難しい文章',
    LongArticleJlptLevel.n2 => 'JLPT N2相当（中上級）の語彙・文法を中心に使う文章',
    LongArticleJlptLevel.n3 => 'JLPT N3相当（中級）の語彙・文法を中心に使う、易しめの文章',
  };

  static String _loosenessDescription(LongArticleLooseness looseness) =>
      switch (looseness) {
        LongArticleLooseness.level1 => '雑談・世間話のような、くだけた話し言葉に近い文体',
        LongArticleLooseness.level2 => 'やや砕けた、日常会話寄りの文体',
        LongArticleLooseness.level3 => '標準的な、丁寧体を中心としたニュートラルな文体',
        LongArticleLooseness.level4 => 'ややかしこまった、説明的な文体',
        LongArticleLooseness.level5 => '学術的・論説的で、硬めの書き言葉',
      };

  static String buildPrompt(LongArticleGenerationSettings settings) {
    return 'あなたは日本語学習教材制作者です。日本語学習者向けの読み物を1つ作成してください。\n'
        '\n'
        '【条件】\n'
        '- キーワード/話題: ${settings.keyword}\n'
        '- レベル: ${_jlptDescription(settings.jlptLevel)}\n'
        '- 文体: ${_loosenessDescription(settings.looseness)}\n'
        '- 目安の文字数: ${settings.length.targetCharacterCount}字程度\n'
        '\n'
        '【出力形式（このJSON形式のみで回答し、前後に説明文を付けないでください）】\n'
        '{"body": "（ここに生成した文章本文）"}';
  }

  static Uri buildSearchUrl(LongArticleGenerationSettings settings) =>
      GoogleAiSearch.buildUrl(
        GoogleAiSearch.withJapanesePrefix(buildPrompt(settings)),
      );

  /// [ChromeAiSubmitMixin.chromeAiSend]へそのまま渡せる形。
  /// 生成言語は常に日本語固定のため、URLのプリフィル言語も'ja'で組み立てる
  /// （UI表示言語とは独立）。
  static ChromeAiLaunchPlan buildLaunchPlan(
    LongArticleGenerationSettings settings,
  ) => GoogleAiSearch.buildLaunchPlan(prompt: buildPrompt(settings), lang: 'ja');
}
