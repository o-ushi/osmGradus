import 'long_article_comprehension_check.dart';
import 'long_article_vocab_word.dart';

/// [LongArticleResponseParser.parseResult]の戻り値。長文本文に加え、
/// 同梱されていれば1秒チェック用クイズ・語彙テスト用単語を保持する。
class LongArticleGenerationResult {
  const LongArticleGenerationResult({
    required this.body,
    this.comprehensionCheck,
    this.vocabTestWords = const [],
  });

  final String body;
  final LongArticleComprehensionCheck? comprehensionCheck;

  /// 語彙テスト用単語（最大9語）。未抽出・旧形式レスポンスでは空配列。
  final List<LongArticleVocabWord> vocabTestWords;
}
