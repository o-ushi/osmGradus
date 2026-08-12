import 'google_ai_search.dart';

/// osmWashabeの `AIPromptTemplate.batchPrompt` をそのまま移植したプロンプト。
/// 「Chrome AIで開く」ボタンから、この文言をGoogle検索（AIモード）に
/// 引き渡してお題を一括生成させる。
class AIPromptTemplate {
  AIPromptTemplate._();

  static const String batchPrompt =
      'あなたは日本語スピーチ練習用のお題を作成するアシスタントです。\n'
      '以下3カテゴリのお題を、それぞれ10問ずつ作成してください。\n'
      '\n'
      '【出力形式（この見出しを必ず使う）】\n'
      '\n'
      '【日常】（45秒スピーチ・10問）\n'
      '1. （質問文）\n'
      '2. （質問文）\n'
      '…（10問）\n'
      '\n'
      '【ビジネス】（45秒スピーチ・10問）\n'
      '1. （質問文）\n'
      '…（10問）\n'
      '\n'
      '【シチュエーション】（15秒準備＋60秒発話・10問）\n'
      '1. 状況：（状況の文章）／条件：（守るべき条件）\n'
      '…（10問）\n'
      '\n'
      '【ルール】\n'
      '- 見出し行は必ず【日常】【ビジネス】【シチュエーション】を付ける\n'
      '- 1行に1問だけ書く\n'
      '- 質問文・状況文だけを書き、解説や挨拶は不要\n'
      '- 日本語で、自然で話しやすい表現にする\n'
      '- 日常は私生活・趣味・経験など、ビジネスは職場・取引・上司同僚などの場面を想定する';

  static Uri buildSearchUrl() =>
      GoogleAiSearch.buildUrl(GoogleAiSearch.withJapanesePrefix(batchPrompt));
}
