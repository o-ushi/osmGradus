import 'google_ai_search.dart';

/// レイヤーⅤ「発音課題の取り込み」用のChrome AIプロンプト。
/// `AIPromptTemplate.batchPrompt`（お題の一括生成）と同じURL組み立て方式を
/// 使うが、固定文で5カテゴリ×5文（計25文）の発音練習用短文をJSON配列形式で
/// 生成させる点が異なる。
abstract final class PronunciationExerciseAiPrompt {
  PronunciationExerciseAiPrompt._();

  static const String batchPrompt =
      'あなたは日本語発音練習用の短文を作成するアシスタントです。\n'
      'ベトナム語母語話者が苦手としやすい次の5カテゴリについて、'
      'それぞれ5文ずつ（合計25文）作成してください。\n'
      '\n'
      '- tsu: 「つ」\n'
      '- zRow: 「ざ・ず・ぞ」\n'
      '- rRow: ラ行\n'
      '- longVowel: 長音\n'
      '- sokuon: 促音\n'
      '\n'
      '【作成ルール】\n'
      '- 各文には、そのカテゴリの対象音が実際に含まれていること'
      '（例: sokuonなら「っ」を含む単語を必ず入れる。他のカテゴリも同様）\n'
      '- 1文は短く、日本語学習者が読み上げやすい自然な表現にする\n'
      '- 1文は原則としてそのカテゴリの発音1つに集中させる\n'
      '- 長音・促音は、対象部分がどこか一目で分かる文にする\n'
      '- readingは文全体をひらがなのみで表記する\n'
      '- targetExpressionsはreading内に実際に含まれる文字列にする\n'
      '\n'
      '【出力形式（このJSON配列のみで回答し、前後に説明文を付けないでください）】\n'
      '[\n'
      '  {"category": "tsu", "sentence": "（日本語の文）", '
      '"reading": "（全てひらがなの読み）", '
      '"targetExpressions": ["（reading内の対象表現）"], '
      '"vietnameseHint": "（ベトナム語での発音の注意点）", '
      '"evaluationPoint": "（日本語での評価観点）"},\n'
      '  ...（tsu/zRow/rRow/longVowel/sokuonそれぞれ5件ずつ、合計25件）\n'
      ']\n'
      '\n'
      'categoryの値は必ず tsu / zRow / rRow / longVowel / sokuon のいずれかに'
      'してください。';

  static Uri buildSearchUrl() =>
      GoogleAiSearch.buildUrl(GoogleAiSearch.withJapanesePrefix(batchPrompt));
}
