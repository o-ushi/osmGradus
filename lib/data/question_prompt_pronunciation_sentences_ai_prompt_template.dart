import '../models/question_prompt.dart';
import 'google_ai_search.dart';

/// レイヤーⅤ「問題作成」（Step 6）用：問題文に関連した発音練習用の短文を
/// [sentenceCount]個、Chrome AIに作成させるプロンプト。
///
/// レイヤーⅠの単語抽出（[QuestionPromptVocabExtractionAiPromptTemplate]）と
/// 同じく、単発の依頼で完結させる（追加のAI往復なし）。生成した短文は
/// 「ランダム」（[Layer5Screen]）と同型のセッションUIへ、既存プールの代わりに
/// この問題文専用の出題プールとしてそのまま渡す。
abstract final class QuestionPromptPronunciationSentencesAiPromptTemplate {
  QuestionPromptPronunciationSentencesAiPromptTemplate._();

  static const sentenceCount = 10;

  /// カテゴリのstorageKey（[PronunciationCategoryLabel.storageKey]と同じ値）。
  /// AI出力・解析の両方でこの文字列をそのまま使う。
  static const _jsonSchema = '''
[
  {"text": "短文（日本語）", "reading": "かな読み", "category": "tsu"},
  {"text": "短文（日本語）", "reading": "かな読み", "category": "zRow"},
  {"text": "短文（日本語）", "reading": "かな読み", "category": "rRow"},
  {"text": "短文（日本語）", "reading": "かな読み", "category": "longVowel"},
  {"text": "短文（日本語）", "reading": "かな読み", "category": "sokuon"}
]''';

  /// [prompt]（本文・シチュエーションの条件文があればそれも含む）から
  /// 短文生成プロンプトを組み立てる。
  static String buildPrompt(QuestionPrompt prompt) {
    final buffer = StringBuffer()
      ..writeln(
        'あなたは日本語発音指導の専門家です。以下の【問題文】に関連した、'
        '日本語学習者向けの発音練習用の短文を$sentenceCount個作成してください。',
      )
      ..writeln()
      ..writeln('【問題文】')
      ..writeln(prompt.body);
    final condition = prompt.situationCondition;
    if (condition != null && condition.isNotEmpty) {
      buffer.writeln(condition);
    }

    buffer
      ..writeln()
      ..writeln('【作成ルール】')
      ..writeln(
        '1. 発音ドリルのためだけの無関係な文にせず、問題文の語彙・場面・'
        'テーマを引き継いだ、関連性のある短文にしてください。',
      )
      ..writeln(
        '2. 次の5つの発音カテゴリ（tsu=「つ」、zRow=「ざ・ず・ぞ」、'
        'rRow=ラ行、longVowel=長音、sokuon=促音）が、それぞれおおむね'
        '均等（目安：各2文）になるようにしてください。',
      )
      ..writeln('3. 学習者が声に出して読みやすい、短く自然な文にしてください。')
      ..writeln()
      ..writeln('【出力形式（このJSON配列のみで回答し、前後に説明文を付けないでください）】')
      ..writeln(_jsonSchema)
      ..writeln()
      ..writeln(
        'categoryは tsu/zRow/rRow/longVowel/sokuon のいずれかにしてください。'
        'ちょうど$sentenceCount件返してください。',
      );
    return buffer.toString();
  }

  static ChromeAiLaunchPlan buildLaunchPlan({required QuestionPrompt prompt}) {
    final text = buildPrompt(prompt);
    return GoogleAiSearch.buildLaunchPlan(prompt: text, lang: 'ja');
  }
}
