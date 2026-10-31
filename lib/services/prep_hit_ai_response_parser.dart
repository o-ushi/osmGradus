import '../models/prep_hit_evaluation.dart';
import 'ai_json_extractor.dart';

/// [PrepHitAiResponseParser.parse]の結果。
class PrepHitAiParseResult {
  const PrepHitAiParseResult({
    required this.rawResponse,
    this.evaluation,
    this.errorMessage,
  });

  final String rawResponse;

  /// 解析できたPREP★・的中度★。解析失敗ならnull。
  final PrepHitEvaluation? evaluation;

  final String? errorMessage;

  bool get isSuccess => evaluation != null;
}

/// Chrome AIの回答（[PrepHitAiPromptTemplate.buildPrompt]への回答）から
/// JSONオブジェクト部分を抽出し、1ラウンド分のPREP★・的中度★へ変換する
/// （osmCogitoの`CogitoEvaluationResponseParser`の移植）。
abstract final class PrepHitAiResponseParser {
  static PrepHitAiParseResult parse(String rawResponse) {
    final trimmed = rawResponse.trim();
    if (trimmed.isEmpty) {
      return PrepHitAiParseResult(
        rawResponse: rawResponse,
        errorMessage: 'empty response',
      );
    }

    final decoded = AiJsonExtractor.extractFirst<Map<String, dynamic>>(
      trimmed,
      open: '{',
      close: '}',
      accept: (decoded) =>
          decoded is Map &&
          (decoded['prepStars'] is num || decoded['predStars'] is num) &&
          decoded['hitStars'] is num,
    );
    if (decoded == null) {
      return PrepHitAiParseResult(
        rawResponse: rawResponse,
        errorMessage: 'no valid JSON object found in response',
      );
    }

    // 書き出しはprep*。旧プロンプト/回答のpred*も読み取る。
    final prepRaw = (decoded['prepStars'] ?? decoded['predStars']) as num;
    final hitRaw = decoded['hitStars'] as num;
    return PrepHitAiParseResult(
      rawResponse: rawResponse,
      evaluation: PrepHitEvaluation(
        prepStars: prepRaw.round().clamp(1, 5),
        hitStars: hitRaw.round().clamp(1, 5),
        prepAdvice: _trimmedStringOrNull(
          decoded['prepAdvice'] ?? decoded['predAdvice'],
        ),
        hitAdvice: _trimmedStringOrNull(decoded['hitAdvice']),
        modelAnswer: _trimmedStringOrNull(decoded['modelAnswer']),
        modelAnswerRomaji: _trimmedStringOrNull(decoded['modelAnswerRomaji']),
        modelAnswerVi: _trimmedStringOrNull(decoded['modelAnswerVi']),
      ),
    );
  }

  static String? _trimmedStringOrNull(Object? raw) {
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
