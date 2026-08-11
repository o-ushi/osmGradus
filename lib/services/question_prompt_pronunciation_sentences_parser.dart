import '../models/pronunciation_exercise.dart' show PronunciationCategoryLabel;
import '../models/question_prompt_pronunciation_sentence.dart';
import 'ai_json_extractor.dart';

/// [QuestionPromptPronunciationSentencesParser.parse]の結果。
class QuestionPromptPronunciationSentencesParseResult {
  const QuestionPromptPronunciationSentencesParseResult({
    required this.rawResponse,
    this.sentences,
    this.errorMessage,
  });

  final String rawResponse;

  /// 解析できた短文一覧（最大10件）。解析に失敗した場合、または1件も
  /// 有効な短文が無かった場合はnull。
  final List<QuestionPromptPronunciationSentence>? sentences;

  final String? errorMessage;

  bool get isSuccess => sentences != null;
}

/// [QuestionPromptPronunciationSentencesAiPromptTemplate.buildPrompt]への
/// 回答からJSON配列を抜き出し、[QuestionPromptPronunciationSentence]の一覧へ
/// 変換する（[QuestionPromptVocabExtractionParser]と同じく、壊れた要素は
/// その位置だけ読み飛ばし、全体を失敗にはしない）。
abstract final class QuestionPromptPronunciationSentencesParser {
  static const maxSentences = 10;

  static QuestionPromptPronunciationSentencesParseResult parse(
    String rawResponse,
  ) {
    final trimmed = rawResponse.trim();
    if (trimmed.isEmpty) {
      return QuestionPromptPronunciationSentencesParseResult(
        rawResponse: rawResponse,
        errorMessage: 'empty response',
      );
    }

    final decoded = AiJsonExtractor.extractFirst<List<dynamic>>(
      trimmed,
      open: '[',
      close: ']',
      accept: (decoded) => decoded is List && decoded.isNotEmpty,
    );
    if (decoded == null) {
      return QuestionPromptPronunciationSentencesParseResult(
        rawResponse: rawResponse,
        errorMessage: 'no valid JSON array found in response',
      );
    }

    final sentences = <QuestionPromptPronunciationSentence>[];
    for (final item in decoded) {
      final parsed = _tryParseItem(item);
      if (parsed == null) continue;
      sentences.add(parsed);
      if (sentences.length >= maxSentences) break;
    }
    if (sentences.isEmpty) {
      return QuestionPromptPronunciationSentencesParseResult(
        rawResponse: rawResponse,
        errorMessage: 'no valid sentences parsed',
      );
    }

    return QuestionPromptPronunciationSentencesParseResult(
      rawResponse: rawResponse,
      sentences: sentences,
    );
  }

  static QuestionPromptPronunciationSentence? _tryParseItem(dynamic item) {
    if (item is! Map) return null;
    try {
      final text = (item['text'] as String).trim();
      if (text.isEmpty) return null;
      final categoryRaw = item['category'] as String?;
      if (categoryRaw == null) return null;
      final category = PronunciationCategoryLabel.fromStorageKey(categoryRaw);
      return QuestionPromptPronunciationSentence(
        text: text,
        reading: (item['reading'] as String? ?? '').trim(),
        category: category,
      );
    } catch (_) {
      return null;
    }
  }
}
