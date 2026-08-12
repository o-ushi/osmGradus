import 'long_article_comprehension_check.dart';

/// [LongArticleResponseParser.parseResult]の戻り値。長文本文に加え、
/// 同梱されていれば1秒チェック用クイズを保持する。
class LongArticleGenerationResult {
  const LongArticleGenerationResult({required this.body, this.comprehensionCheck});

  final String body;
  final LongArticleComprehensionCheck? comprehensionCheck;
}
