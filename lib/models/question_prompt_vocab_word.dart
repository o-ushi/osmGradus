/// レイヤーⅠ「問題作成」（Step 2）でChrome AIが問題文から抽出する単語1件の
/// スナップショット。[QuestionPrompt]側に複製で持たせ、レイヤーⅠ内語彙テスト
/// （Step 3）の出題・不正解時の単語帳登録（訳・例文の再問い合わせ禁止）・
/// 総評での再表示に、追加のAI往復なしで使い回す。
class QuestionPromptVocabWord {
  const QuestionPromptVocabWord({
    required this.word,
    this.reading = '',
    this.pos = '',
    this.jlpt = '',
    required this.meaning,
    this.example = '',
    this.exampleTranslation = '',
  });

  /// 問題文中の表記。
  final String word;

  /// かな読み。
  final String reading;

  /// 品詞。
  final String pos;

  /// 難易度目安（N1/N2/N3等）。
  final String jlpt;

  /// アプリの表示言語に合わせた短い訳。
  final String meaning;

  /// その語を使った短い例文。
  final String example;

  /// [example]の訳（任意）。
  final String exampleTranslation;

  factory QuestionPromptVocabWord.fromJson(Map<String, dynamic> json) =>
      QuestionPromptVocabWord(
        word: json['word'] as String? ?? '',
        reading: json['reading'] as String? ?? '',
        pos: json['pos'] as String? ?? '',
        jlpt: json['jlpt'] as String? ?? '',
        meaning: json['meaning'] as String? ?? '',
        example: json['example'] as String? ?? '',
        exampleTranslation: json['exampleTranslation'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
    'word': word,
    if (reading.isNotEmpty) 'reading': reading,
    if (pos.isNotEmpty) 'pos': pos,
    if (jlpt.isNotEmpty) 'jlpt': jlpt,
    'meaning': meaning,
    if (example.isNotEmpty) 'example': example,
    if (exampleTranslation.isNotEmpty) 'exampleTranslation': exampleTranslation,
  };
}
