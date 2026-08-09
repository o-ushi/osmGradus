import 'vocabulary_level.dart';

/// 単語テスト（レイヤーⅠ「語彙を増やす」）用の標準／取り込み語彙の1件。
/// 標準語は[JlptVocabBankService]が仮想[VocabularyEntry]へ変換し、
/// Chrome AI取り込みは[VocabularyService]へ追記する。
class JlptVocabWord {
  const JlptVocabWord({
    required this.level,
    required this.word,
    this.reading = '',
    this.exampleSentence = '',
    required this.translation,
    this.translationLang = 'vi',
  });

  final VocabularyLevel level;
  final String word;
  final String reading;
  final String exampleSentence;
  final String translation;
  final String translationLang;
}
