import 'google_ai_search.dart';

/// osmWashabeの `AIPromptTemplate.batchPrompt` を移植したプロンプト。
/// 「Chrome AIで開く」ボタンから、この文言をGoogle検索（AIモード）に
/// 引き渡してお題を一括生成させる。
///
/// `question-prompt-tabs.md` Step 4から見出しは【その他】／【シチュエーション】
/// の2つ（旧【日常】【ビジネス】は廃止。読み込み側は互換のため引き続き
/// 両方を受け付けるが、新規に出力するプロンプトはこの2見出しのみ）。
class AIPromptTemplate {
  AIPromptTemplate._();

  static const String batchPrompt =
      'あなたは日本語スピーチ練習用のお題を作成するアシスタントです。\n'
      '以下2カテゴリのお題を、それぞれ10問ずつ作成してください。\n'
      '\n'
      '【出力形式（この見出しを必ず使う）】\n'
      '\n'
      '【その他】（45秒スピーチ・10問）\n'
      '1. （質問文）\n'
      '2. （質問文）\n'
      '…（10問）\n'
      '\n'
      '【シチュエーション】（15秒準備＋60秒発話・10問）\n'
      '1. 状況：（状況の文章）／条件：（守るべき条件）\n'
      '…（10問）\n'
      '\n'
      '【ルール】\n'
      '- 見出し行は必ず【その他】【シチュエーション】を付ける\n'
      '- 1行に1問だけ書く\n'
      '- 質問文・状況文だけを書き、解説や挨拶は不要\n'
      '- 日本語で、自然で話しやすい表現にする\n'
      '- 「その他」は私生活・趣味・経験・職場・取引・上司同僚など、'
      'シチュエーション以外の幅広い話題を想定する';

  static Uri buildSearchUrl() =>
      GoogleAiSearch.buildUrl(GoogleAiSearch.withJapanesePrefix(batchPrompt));
}
