import '../data/long_article_ai_prompt.dart';
import '../models/long_article_comprehension_check.dart';
import '../models/long_article_generation_result.dart';
import '../models/long_article_vocab_word.dart';
import 'ai_json_extractor.dart';

/// [LongArticleAiPrompt.buildPrompt]への回答
/// （`{"body": "...", "comprehensionCheck": {...}, "vocabTestWords": [...]}`）
/// を解析し、本文・1秒チェック・語彙テスト用単語を取り出す。JSON抽出は
/// [AiJsonExtractor]に委ねる。
abstract final class LongArticleResponseParser {
  /// 本文のみを取り出す（後方互換用。[parseResult]と同じ抽出結果から`body`だけ返す）。
  static String? parse(String rawResponse) => parseResult(rawResponse)?.body;

  /// 本文・1秒チェック・語彙テスト用単語を取り出す。`comprehensionCheck`や
  /// `vocabTestWords`が無い・不完全・不正な場合でも`body`が妥当なら結果を返す
  /// （それぞれ`null`／空配列になるだけ）。
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
      vocabTestWords: _vocabTestWordsFromJson(decoded['vocabTestWords']),
    );
  }

  /// 不正・欠落した語はスキップし、`meaningEn`/`meaningVi`が両方空の語は
  /// 採用しない。上限[LongArticleAiPrompt.vocabMaxWords]語でtruncateする。
  static List<LongArticleVocabWord> _vocabTestWordsFromJson(Object? raw) {
    if (raw is! List) return const [];
    final result = <LongArticleVocabWord>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final LongArticleVocabWord word;
      try {
        word = LongArticleVocabWord.fromJson(Map<String, dynamic>.from(item));
      } catch (_) {
        continue;
      }
      if (word.word.isEmpty) continue;
      if (word.meaningEn.isEmpty && word.meaningVi.isEmpty) continue;
      result.add(word);
      if (result.length >= LongArticleAiPrompt.vocabMaxWords) break;
    }
    return result;
  }
}
