import '../models/vocabulary_evaluation.dart';
import 'ai_evaluation_parse_result.dart';
import 'ai_evaluation_response_parser.dart';

typedef VocabularyAiParseResult = AiEvaluationParseResult<VocabularyEvaluation>;

/// Chrome AIの回答（[VocabularyAiPromptTemplate.evaluationPrompt]への回答）
/// からJSON部分を抽出し、[VocabularyEvaluation]へ変換する。
/// 解析そのものは[PronunciationAiResponseParser]と共有の
/// [AiEvaluationResponseParser]に委ねる。
abstract final class VocabularyAiResponseParser {
  /// アプリ側で管理する評価スキーマのバージョン。AIには依頼せず、
  /// 解析に成功した場合はここで固定値を補う。
  static const evaluationVersion = 'v1';

  /// [rawResponse]を解析する。[languageCode]は、この回答を依頼した時点の
  /// アプリ表示言語（'ja'/'en'/'vi'）。
  static VocabularyAiParseResult parse(
    String rawResponse, {
    String languageCode = 'ja',
  }) {
    return AiEvaluationResponseParser.parse<VocabularyEvaluation>(
      rawResponse: rawResponse,
      languageCode: languageCode,
      evaluationVersion: evaluationVersion,
      acceptMap: (decoded) => decoded.containsKey('overallScore'),
      fromJson: VocabularyEvaluation.fromJson,
    );
  }
}
