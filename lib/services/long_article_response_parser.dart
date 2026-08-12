import '../models/long_article_comprehension_check.dart';
import '../models/long_article_generation_result.dart';
import 'ai_json_extractor.dart';

/// [LongArticleAiPrompt.buildPrompt]への回答（`{"body": "...", "comprehensionCheck": {...}}`）
/// を解析し、本文・1秒チェックを取り出す。JSON抽出は[AiJsonExtractor]に委ねる。
abstract final class LongArticleResponseParser {
  /// 本文のみを取り出す（後方互換用。[parseResult]と同じ抽出結果から`body`だけ返す）。
  static String? parse(String rawResponse) => parseResult(rawResponse)?.body;

  /// 本文と1秒チェックの両方を取り出す。`comprehensionCheck`が無い・不完全・
  /// 不正な場合でも`body`が妥当なら結果を返す（`comprehensionCheck`のみnull）。
  static LongArticleGenerationResult? parseResult(String rawResponse) {
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
    return LongArticleGenerationResult(
      body: (decoded['body'] as String).trim(),
      comprehensionCheck: LongArticleComprehensionCheck.fromJsonOrNull(
        decoded['comprehensionCheck'],
      ),
    );
  }
}
