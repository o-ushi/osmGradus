import 'ai_json_extractor.dart';

/// [LongArticleAiPrompt.buildPrompt]への回答（`{"body": "..."}`）を解析し、
/// 本文を取り出す。JSON抽出は[AiJsonExtractor]に委ねる。
abstract final class LongArticleResponseParser {
  static String? parse(String rawResponse) {
    final decoded = AiJsonExtractor.extractFirst<Map<String, dynamic>>(
      rawResponse.trim(),
      open: '{',
      close: '}',
      accept: (decoded) =>
          decoded is Map &&
          decoded['body'] is String &&
          (decoded['body'] as String).trim().isNotEmpty,
    );
    if (decoded == null) return null;
    return (decoded['body'] as String).trim();
  }
}
