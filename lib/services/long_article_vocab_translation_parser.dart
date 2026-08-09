import 'ai_json_extractor.dart';

/// 1単語分の訳・読み・例文（Chrome AIの回答1件分）。
class LongArticleVocabTranslationEntry {
  const LongArticleVocabTranslationEntry({
    required this.reading,
    required this.translation,
    required this.exampleSentence,
  });

  final String reading;
  final String translation;
  final String exampleSentence;
}

/// [LongArticleVocabTranslationParser.parse]の結果。
class LongArticleVocabTranslationParseResult {
  const LongArticleVocabTranslationParseResult({
    required this.rawResponse,
    this.entries,
    this.errorMessage,
  });

  final String rawResponse;

  /// 解析できた要素一覧。依頼した単語配列と同じ位置に対応する（その位置の
  /// 要素が壊れていた場合はnullのままにし、位置がずれて別の単語に誤って
  /// 割り当たらないようにする）。
  final List<LongArticleVocabTranslationEntry?>? entries;

  final String? errorMessage;

  bool get isSuccess => entries != null;
}

/// [LongArticleVocabTranslationPrompt.buildPrompt]への回答からJSON配列部分を
/// 抽出し、依頼した単語と同じ並びの[LongArticleVocabTranslationEntry?]
/// リストへ変換する（osmCogitoの`CogitoVocabTranslationResponseParser`を
/// 移植）。1件でも欠けたら全体を失敗にはせず、位置ごとにnullを読み飛ばして
/// 反映できるようにする。
abstract final class LongArticleVocabTranslationParser {
  static LongArticleVocabTranslationParseResult parse(String rawResponse) {
    final trimmed = rawResponse.trim();
    if (trimmed.isEmpty) {
      return LongArticleVocabTranslationParseResult(
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
      return LongArticleVocabTranslationParseResult(
        rawResponse: rawResponse,
        errorMessage: 'no valid JSON array found in response',
      );
    }

    final entries = <LongArticleVocabTranslationEntry?>[
      for (final item in decoded) _tryParseItem(item),
    ];
    return LongArticleVocabTranslationParseResult(
      rawResponse: rawResponse,
      entries: entries,
    );
  }

  static LongArticleVocabTranslationEntry? _tryParseItem(dynamic item) {
    if (item is! Map) return null;
    try {
      final translation = (item['translation'] as String).trim();
      if (translation.isEmpty) return null;
      final reading = (item['reading'] as String? ?? '').trim();
      final exampleSentence = (item['exampleSentence'] as String? ?? '')
          .trim();
      return LongArticleVocabTranslationEntry(
        reading: reading,
        translation: translation,
        exampleSentence: exampleSentence,
      );
    } catch (_) {
      return null;
    }
  }
}
