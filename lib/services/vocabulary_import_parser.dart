import '../models/jlpt_vocab_word.dart';
import '../models/vocabulary_level.dart';
import 'ai_json_extractor.dart';

/// [VocabularyImportParser.parse]の結果。
class VocabularyImportResult {
  const VocabularyImportResult({
    required this.words,
    required this.rejectedCount,
  });

  /// 検証を通過した取り込み候補（レベル付き、バッチ内の単語重複は除去済み）。
  final List<JlptVocabWord> words;

  /// JSON配列内にはあったが、必須項目の欠落・レベル不正・バッチ内重複などで
  /// 除外された件数。
  final int rejectedCount;

  bool get isEmpty => words.isEmpty;
}

/// [VocabularyAiImportPrompt.batchPrompt]への回答（N1/N2/N3×20語の
/// JSON配列）を解析し、[JlptVocabWord]のリストへ変換する。
///
/// JSON抽出は[AiJsonExtractor]に委ね、`level`と`word`キーを持つ要素の配列
/// である最初の妥当なJSONを採用する。不完全な項目は読み飛ばす。
abstract final class VocabularyImportParser {
  static VocabularyImportResult parse(String rawResponse) {
    final decoded = AiJsonExtractor.extractFirst<List<dynamic>>(
      rawResponse.trim(),
      open: '[',
      close: ']',
      accept: (decoded) =>
          decoded is List &&
          decoded.isNotEmpty &&
          decoded.first is Map &&
          (decoded.first as Map).containsKey('level') &&
          (decoded.first as Map).containsKey('word'),
    );
    if (decoded == null) {
      return const VocabularyImportResult(words: [], rejectedCount: 0);
    }

    final seenWords = <String>{};
    final words = <JlptVocabWord>[];
    var rejected = 0;

    for (final item in decoded) {
      if (item is! Map) {
        rejected++;
        continue;
      }
      final word = _tryBuildWord(Map<String, dynamic>.from(item));
      if (word == null) {
        rejected++;
        continue;
      }
      // レベルをまたいでも同一表記は1件だけ取り込む。
      if (!seenWords.add(word.word)) {
        rejected++;
        continue;
      }
      words.add(word);
    }

    return VocabularyImportResult(words: words, rejectedCount: rejected);
  }

  static JlptVocabWord? _tryBuildWord(Map<String, dynamic> json) {
    final levelKey = json['level'];
    final word = json['word'];
    final translation = json['translation'];

    if (levelKey is! String) return null;
    final level = _tryParseLevel(levelKey);
    if (level == null) return null;

    if (word is! String || word.trim().isEmpty) return null;
    if (translation is! String || translation.trim().isEmpty) return null;

    final reading = json['reading'];
    final readingText = reading is String ? reading.trim() : '';

    final exampleSentence = json['exampleSentence'];
    final exampleSentenceText = exampleSentence is String
        ? exampleSentence.trim()
        : '';

    final translationLangRaw = json['translationLang'];
    final translationLang = switch (translationLangRaw) {
      'en' => 'en',
      'vi' => 'vi',
      _ => 'vi',
    };

    return JlptVocabWord(
      level: level,
      word: word.trim(),
      reading: readingText,
      exampleSentence: exampleSentenceText,
      translation: translation.trim(),
      translationLang: translationLang,
    );
  }

  static VocabularyLevel? _tryParseLevel(String key) {
    final normalized = key.trim().toLowerCase();
    return switch (normalized) {
      'n1' => VocabularyLevel.n1,
      'n2' => VocabularyLevel.n2,
      'n3' => VocabularyLevel.n3,
      _ => null,
    };
  }
}
