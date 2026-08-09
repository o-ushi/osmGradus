/// Chrome AI 評価レスポンスの解析結果（語彙・発音で共通）。
class AiEvaluationParseResult<T> {
  const AiEvaluationParseResult({
    required this.rawResponse,
    this.evaluation,
    this.errorMessage,
  });

  final String rawResponse;
  final T? evaluation;
  final String? errorMessage;

  bool get isSuccess => evaluation != null;
}
