import '../models/vocabulary_entry.dart';
import 'google_ai_search.dart';

/// 長文読解中にタップ/長押し登録した単語（訳語未入力）へ、Chrome AIで読み・
/// 訳語・例文をまとめて付けさせるプロンプト。osmCogitoの
/// `CogitoVocabTranslationPromptBuilder`を移植——番号付きリストを渡し、
/// 同じ件数・同じ順序のJSON配列を依頼する方式。
abstract final class LongArticleVocabTranslationPrompt {
  LongArticleVocabTranslationPrompt._();

  static const _jsonSchema = '''
[
  {"reading": "読み仮名（ひらがな）", "translation": "対象言語での訳", "exampleSentence": "その単語を使った日本語の例文"},
  {"reading": "読み仮名（ひらがな）", "translation": "対象言語での訳", "exampleSentence": "その単語を使った日本語の例文"}
]''';

  /// 訳の言語（vi/en）。アプリ表示言語が'en'なら英語、それ以外（ja含む）は
  /// ベトナム語を既定にする（[VocabularyEntry.translationLang]の既定と同じ）。
  static String translationLangFor(String appLanguage) =>
      appLanguage == 'en' ? 'en' : 'vi';

  static String _translationLangLabel(String translationLangCode) =>
      translationLangCode == 'en' ? '英語' : 'ベトナム語';

  /// [appLanguage]はアプリ表示言語（'ja'/'en'/'vi'）。出力の訳の言語は
  /// [translationLangFor]が決める（プロンプトの指示文自体は常に日本語）。
  static String buildPrompt(
    List<VocabularyEntry> words, {
    String appLanguage = 'ja',
  }) {
    final label = _translationLangLabel(translationLangFor(appLanguage));
    final buffer = StringBuffer()
      ..writeln(
        'あなたは日本語語彙の指導コーチです。以下は学習者が単語帳へ登録したものの、'
        'まだ訳が付いていない日本語の単語一覧です。各単語について、読み'
        '（ひらがな）、$label での訳、その単語を使った短い日本語の例文を'
        '作成してください。',
      )
      ..writeln()
      ..writeln('【単語一覧】');
    for (var i = 0; i < words.length; i++) {
      buffer.writeln(_wordLine(i + 1, words[i]));
    }
    buffer
      ..writeln()
      ..writeln('【出力形式（このJSON配列のみで回答し、前後に説明文を付けないでください）】')
      ..writeln(_jsonSchema)
      ..writeln()
      ..writeln('配列は単語と同じ件数・同じ順序にしてください。例文は日本語で書いてください。');
    return buffer.toString();
  }

  static String _wordLine(int number, VocabularyEntry entry) {
    final reading = entry.reading.trim();
    return '$number. word: ${entry.word}'
        '${reading.isEmpty ? '' : ' / reading: $reading'}';
  }

  /// プロンプトと、それを開くためのURL（長い場合は貼り付け必須）を返す。
  static ChromeAiLaunchPlan buildLaunchPlan({
    required List<VocabularyEntry> words,
    required String appLanguage,
  }) {
    final prompt = buildPrompt(words, appLanguage: appLanguage);
    return GoogleAiSearch.buildLaunchPlan(
      prompt: prompt,
      lang: translationLangFor(appLanguage),
    );
  }
}
