import 'vocabulary_level.dart';

/// 単語帳に登録する1件（日本語の単語と訳語）。
class VocabularyEntry {
  const VocabularyEntry({
    required this.id,
    required this.word,
    this.reading = '',
    this.exampleSentence = '',
    required this.translation,
    this.translationLang = 'vi',
    this.level = VocabularyLevel.other,
    required this.createdAt,
  });

  final String id;
  final String word;

  /// 読み上げ用のひらがな表記（任意）。空なら[word]をそのまま読み上げる。
  final String reading;

  /// [word]を使った例文（任意）。
  final String exampleSentence;
  final String translation;

  /// 訳語の言語。'vi'（ベトナム語）または'en'（英語）。
  final String translationLang;

  /// JLPTレベル（N1/N2/N3）。レベル分類が無い語は[VocabularyLevel.other]。
  /// 単語テスト（レイヤーⅠ「語彙を増やす」）がレベル別に出題する際に使う。
  final VocabularyLevel level;
  final DateTime createdAt;

  factory VocabularyEntry.fromJson(Map<String, dynamic> json) =>
      VocabularyEntry(
        id: json['id'] as String,
        word: json['word'] as String,
        reading: json['reading'] as String? ?? '',
        exampleSentence: json['exampleSentence'] as String? ?? '',
        translation: json['translation'] as String,
        translationLang: json['translationLang'] as String? ?? 'vi',
        level: VocabularyLevelStorage.fromStorageKey(json['level'] as String?),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'word': word,
    'reading': reading,
    'exampleSentence': exampleSentence,
    'translation': translation,
    'translationLang': translationLang,
    'level': level.storageKey,
    'createdAt': createdAt.toIso8601String(),
  };

  VocabularyEntry copyWith({
    String? word,
    String? reading,
    String? exampleSentence,
    String? translation,
    String? translationLang,
    VocabularyLevel? level,
  }) => VocabularyEntry(
    id: id,
    word: word ?? this.word,
    reading: reading ?? this.reading,
    exampleSentence: exampleSentence ?? this.exampleSentence,
    translation: translation ?? this.translation,
    translationLang: translationLang ?? this.translationLang,
    level: level ?? this.level,
    createdAt: createdAt,
  );
}
