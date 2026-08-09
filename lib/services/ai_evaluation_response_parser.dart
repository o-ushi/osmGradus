import 'ai_evaluation_parse_result.dart';
import 'ai_json_extractor.dart';

/// Chrome AI回答からJSON部分を抽出し、評価モデルへ変換する共通ロジック
/// （[VocabularyAiResponseParser]・[PronunciationAiResponseParser]で共有）。
///
/// JSON抽出そのものは[AiJsonExtractor]に委ね、ここでは「妥当なJSONの中から
/// 呼び出し側が求めるキーを持つ最初のものを採用し、rawResponse・
/// evaluationVersion・languageCodeを補ってモデルへ変換する」という
/// 空文字判定〜抽出〜モデル変換の一連の流れだけを共通化する。
abstract final class AiEvaluationResponseParser {
  /// [rawResponse]を解析する。
  /// - [languageCode]：この回答を依頼した時点のアプリ表示言語（'ja'/'en'/'vi'）。
  /// - [evaluationVersion]：アプリ側で管理する評価スキーマのバージョン。
  /// - [acceptMap]：抽出したJSONオブジェクトが期待する形か判定する
  ///   （例：`overallScore`キーを持つか）。
  /// - [fromJson]：`rawResponse`/`evaluationVersion`/`languageCode`を補った
  ///   JSONから評価モデル[T]を組み立てる。
  static AiEvaluationParseResult<T> parse<T>({
    required String rawResponse,
    required String languageCode,
    required String evaluationVersion,
    required bool Function(Map<String, dynamic>) acceptMap,
    required T Function(Map<String, dynamic> json) fromJson,
  }) {
    final trimmed = rawResponse.trim();
    if (trimmed.isEmpty) {
      return AiEvaluationParseResult<T>(
        rawResponse: rawResponse,
        errorMessage: 'empty response',
      );
    }

    final decoded = AiJsonExtractor.extractFirst<Map<String, dynamic>>(
      trimmed,
      open: '{',
      close: '}',
      accept: (decoded) =>
          decoded is Map<String, dynamic> && acceptMap(decoded),
    );
    if (decoded == null) {
      return AiEvaluationParseResult<T>(
        rawResponse: rawResponse,
        errorMessage: 'no valid JSON object found in response',
      );
    }

    try {
      final evaluation = fromJson({
        ...decoded,
        'rawResponse': rawResponse,
        'evaluationVersion': evaluationVersion,
        'languageCode': languageCode,
      });
      return AiEvaluationParseResult<T>(
        rawResponse: rawResponse,
        evaluation: evaluation,
      );
    } catch (e) {
      return AiEvaluationParseResult<T>(
        rawResponse: rawResponse,
        errorMessage: 'failed to build evaluation from JSON: $e',
      );
    }
  }
}
