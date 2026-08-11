import '../models/question_prompt_vocab_word.dart';
import 'ai_json_extractor.dart';

/// [QuestionPromptVocabExtractionParser.parse]の結果。
class QuestionPromptVocabExtractionParseResult {
  const QuestionPromptVocabExtractionParseResult({
    required this.rawResponse,
    this.words,
    this.errorMessage,
  });

  final String rawResponse;

  /// 解析できた単語一覧（[QuestionPromptVocabExtractionParser.maxWords]件まで）。
  /// 解析に失敗した場合、または1件も有効な単語が無かった場合はnull。
  final List<QuestionPromptVocabWord>? words;

  final String? errorMessage;

  bool get isSuccess => words != null;
}

/// [QuestionPromptVocabExtractionAiPromptTemplate.buildPrompt]への回答から
/// `{"words": [...]}`形式のJSONを抜き出し、[QuestionPromptVocabWord]の一覧へ
/// 変換する（[LongArticleVocabTranslationParser]と同じく、壊れた要素は
/// その位置だけ読み飛ばし、全体を失敗にはしない）。
abstract final class QuestionPromptVocabExtractionParser {
  static const maxWords = 5;

  static QuestionPromptVocabExtractionParseResult parse(String rawResponse) {
    final trimmed = rawResponse.trim();
    if (trimmed.isEmpty) {
      return QuestionPromptVocabExtractionParseResult(
        rawResponse: rawResponse,
        errorMessage: 'empty response',
      );
    }

    final decoded = AiJsonExtractor.extractFirst<Map<String, dynamic>>(
      trimmed,
      open: '{',
      close: '}',
      accept: (decoded) => decoded is Map && decoded['words'] is List,
    );
    if (decoded == null) {
      return QuestionPromptVocabExtractionParseResult(
        rawResponse: rawResponse,
        errorMessage: 'no valid JSON object found in response',
      );
    }

    final words = <QuestionPromptVocabWord>[];
    for (final item in decoded['words'] as List) {
      final parsed = _tryParseItem(item);
      if (parsed == null) continue;
      words.add(parsed);
      if (words.length >= maxWords) break;
    }
    if (words.isEmpty) {
      return QuestionPromptVocabExtractionParseResult(
        rawResponse: rawResponse,
        errorMessage: 'no valid words parsed',
      );
    }

    return QuestionPromptVocabExtractionParseResult(
      rawResponse: rawResponse,
      words: words,
    );
  }

  static QuestionPromptVocabWord? _tryParseItem(dynamic item) {
    if (item is! Map) return null;
    try {
      final word = (item['word'] as String).trim();
      if (word.isEmpty) return null;
      return QuestionPromptVocabWord(
        word: word,
        reading: (item['reading'] as String? ?? '').trim(),
        pos: (item['pos'] as String? ?? '').trim(),
        jlpt: (item['jlpt'] as String? ?? '').trim(),
        meaning: (item['meaning'] as String? ?? '').trim(),
        example: (item['example'] as String? ?? '').trim(),
        exampleTranslation: (item['exampleTranslation'] as String? ?? '')
            .trim(),
      );
    } catch (_) {
      return null;
    }
  }
}
