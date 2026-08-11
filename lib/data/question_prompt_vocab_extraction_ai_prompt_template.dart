import '../models/question_prompt.dart';
import 'google_ai_search.dart';
import 'long_article_vocab_translation_prompt.dart';

/// レイヤーⅠ「問題作成」（Step 2）用：問題文から、学習者が文脈理解でつまずき
/// やすい難易度の高い単語を最大[maxWords]個、Chrome AIに抽出させるプロンプト。
///
/// ユーザー提供のGemini案（除外対象・抽出優先度のルール）をベースに、
/// 不正解時にすぐ単語カード登録できるよう「訳・例文の再問い合わせ禁止」
/// （[LongArticleVocabTranslationPrompt]と同じ考え方）で、読み・品詞・
/// 難易度目安・訳・例文・例文訳までを1往復で取得する。
///
/// 訳語（meaning/exampleTranslation）の言語は
/// [LongArticleVocabTranslationPrompt.translationLangFor]と同じ判定
/// （アプリ表示言語が'en'なら英語、それ以外は既定でベトナム語）を使う
/// （[QuestionPromptVocabWord]は将来[VocabularyService]へそのまま登録する
/// 想定のため、[VocabularyEntry.translationLang]と同じ2言語に揃える）。
abstract final class QuestionPromptVocabExtractionAiPromptTemplate {
  QuestionPromptVocabExtractionAiPromptTemplate._();

  static const maxWords = 5;

  static const _jsonSchema = '''
{
  "words": [
    {"word": "問題文中の表記", "reading": "かな読み", "pos": "品詞", "jlpt": "N1〜N3等の目安", "meaning": "対象言語での短い訳", "example": "その語を使った短い自然な例文（日本語）", "exampleTranslation": "例文の対象言語訳"}
  ]
}''';

  static String _translationLangLabel(String translationLangCode) =>
      translationLangCode == 'en' ? '英語' : 'ベトナム語';

  /// [prompt]（本文・シチュエーションの条件文があればそれも含む）から
  /// 抽出プロンプトを組み立てる。[appLanguage]はアプリ表示言語（'ja'/'en'/'vi'）。
  static String buildPrompt(
    QuestionPrompt prompt, {
    String appLanguage = 'ja',
  }) {
    final label = _translationLangLabel(
      LongArticleVocabTranslationPrompt.translationLangFor(appLanguage),
    );
    final buffer = StringBuffer()
      ..writeln(
        'あなたは日本語教育（特にJSSTやBCTなどのビジネス日本語テスト）の専門家です。'
        '以下の【問題文】から、学習者が文脈理解でつまずきやすい難易度の高い単語を'
        '最大$maxWordsつ抽出してください。',
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
      ..writeln('【抽出ルール】')
      ..writeln('1. 除外対象（絶対に抽出しない）:')
      ..writeln('   - 代名詞・指示語（私、あなた、これ、そこ、どこ 等）')
      ..writeln('   - 助詞・助動詞・形式名詞・接尾辞（〜の、〜です、こと、もの、人、〜たち 等）')
      ..writeln('   - 初級・基本語彙（行く、見る、する、良い、広い、ボランティア 等）')
      ..writeln('   - オノマトペ・擬音語・擬態語（しっかり、ゆっくり、どんどん 等）')
      ..writeln('2. 抽出優先度:')
      ..writeln('   - 高: JLPT N1〜N2相当、ビジネス・社会的抽象名詞、サ変動詞、和語動詞、複合語・慣用表現')
      ..writeln('   - 低: JLPT N3以下の日常語・外来語')
      ..writeln('3. 問題文中の語彙をスコアリングし、難易度の高い上位最大$maxWordsつを厳選してください。')
      ..writeln(
        '4. どうしても$maxWordsつ取れない単純な問題文では、$maxWords未満でもかまいません'
        '（0件は避け、取れるだけ出してください）。',
      )
      ..writeln()
      ..writeln('【アプリ用・必須の追加出力】')
      ..writeln(
        '不正解時にすぐ単語カード登録できるよう、追加のAI往復を不要にしてください。'
        '各単語について必ず次を含めてください: 表記（word）、かな読み（reading）、'
        '品詞（pos）、難易度目安（jlpt、N1/N2/N3等）、$labelでの短い訳（meaning）、'
        'その語を使った短い自然な例文（example、日本語）、例文の$label訳'
        '（exampleTranslation）。',
      )
      ..writeln()
      ..writeln('【出力形式（このJSONのみで回答し、前後に説明文を付けないでください）】')
      ..writeln(_jsonSchema);
    return buffer.toString();
  }

  static ChromeAiLaunchPlan buildLaunchPlan({
    required QuestionPrompt prompt,
    required String appLanguage,
  }) {
    final text = buildPrompt(prompt, appLanguage: appLanguage);
    return GoogleAiSearch.buildLaunchPlan(
      prompt: text,
      lang: LongArticleVocabTranslationPrompt.translationLangFor(appLanguage),
    );
  }
}
