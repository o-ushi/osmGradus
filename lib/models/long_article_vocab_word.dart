/// 長文読解（レイヤーⅠ「長文読解」）でChrome AIが長文生成と同時に抽出する
/// 語彙テスト用単語1件のスナップショット。[LongArticle]側に複製で持たせ、
/// 語彙テスト（9問）の出題・不正解時の単語帳登録・結果詳細での再表示に、
/// 追加のAI往復なしで使い回す。
///
/// [QuestionPromptVocabWord]と異なり、アプリ表示言語の切替後も再生成せずに
/// 済むよう、訳・例文訳をen/vi両方常に持つ。
class LongArticleVocabWord {
  const LongArticleVocabWord({
    required this.word,
    this.reading = '',
    this.pos = '',
    this.jlpt = '',
    required this.meaningEn,
    required this.meaningVi,
    this.example = '',
    this.exampleTranslationEn = '',
    this.exampleTranslationVi = '',
  });

  /// 長文中の表記。
  final String word;

  /// かな読み。
  final String reading;

  /// 品詞（任意）。
  final String pos;

  /// 難易度目安（N1/N2/N3等、任意）。
  final String jlpt;

  final String meaningEn;
  final String meaningVi;

  /// その語を使った日本語の例文。
  final String example;

  /// [example]の英訳（任意だが生成時は推奨）。
  final String exampleTranslationEn;

  /// [example]の越訳（任意だが生成時は推奨）。
  final String exampleTranslationVi;

  /// アプリ表示言語[appLanguage]（'ja'/'en'/'vi'）に対応する訳。
  /// [appLanguage]が`'en'`なら英語、それ以外（ja含む）はベトナム語
  /// （[LongArticleVocabTranslationPrompt.translationLangFor]と同じ判定）。
  String meaningFor(String appLanguage) =>
      appLanguage == 'en' ? meaningEn : meaningVi;

  /// [appLanguage]に対応する[example]の訳。判定は[meaningFor]と同じ。
  String exampleTranslationFor(String appLanguage) =>
      appLanguage == 'en' ? exampleTranslationEn : exampleTranslationVi;

  factory LongArticleVocabWord.fromJson(Map<String, dynamic> json) =>
      LongArticleVocabWord(
        word: json['word'] as String? ?? '',
        reading: json['reading'] as String? ?? '',
        pos: json['pos'] as String? ?? '',
        jlpt: json['jlpt'] as String? ?? '',
        meaningEn: json['meaningEn'] as String? ?? '',
        meaningVi: json['meaningVi'] as String? ?? '',
        example: json['example'] as String? ?? '',
        exampleTranslationEn: json['exampleTranslationEn'] as String? ?? '',
        exampleTranslationVi: json['exampleTranslationVi'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
    'word': word,
    if (reading.isNotEmpty) 'reading': reading,
    if (pos.isNotEmpty) 'pos': pos,
    if (jlpt.isNotEmpty) 'jlpt': jlpt,
    'meaningEn': meaningEn,
    'meaningVi': meaningVi,
    if (example.isNotEmpty) 'example': example,
    if (exampleTranslationEn.isNotEmpty)
      'exampleTranslationEn': exampleTranslationEn,
    if (exampleTranslationVi.isNotEmpty)
      'exampleTranslationVi': exampleTranslationVi,
  };
}
