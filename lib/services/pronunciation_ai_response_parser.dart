import '../models/pronunciation_evaluation.dart';
import 'ai_evaluation_parse_result.dart';
import 'ai_evaluation_response_parser.dart';

typedef PronunciationAiParseResult = AiEvaluationParseResult<PronunciationEvaluation>;

/// Chrome AIの回答（[PronunciationAiPromptTemplate.evaluationPrompt]への回答）
/// からJSON部分を抽出し、[PronunciationEvaluation]へ変換する。
///
/// 解析そのものは[VocabularyAiResponseParser]と共有の
/// [AiEvaluationResponseParser]（JSON抽出は[AiJsonExtractor]、Markdownの
/// コードフェンスや前置き・後書きの説明文を無視して`{...}`を総当たりで探す
/// 共通ロジック）に委ね、ここでは`categoryEvaluations`キーを持つ最初の
/// 妥当なJSONを採用する条件だけを指定する。
abstract final class PronunciationAiResponseParser {
  /// アプリ側で管理する評価スキーマのバージョン。AIには依頼せず、
  /// 解析に成功した場合はここで固定値を補う。
  /// `v2`から、`feedbackJa`/`feedbackVi`/`summaryJa`/`summaryVi`（日本語・
  /// ベトナム語を常に併記）を廃し、依頼時のアプリ表示言語1つだけで書かせる
  /// `feedback`/`summary`に切り替えた
  /// （[PronunciationAiPromptTemplate]・[PronunciationEvaluation]参照）。
  static const evaluationVersion = 'v2';

  /// [rawResponse]を解析する。[languageCode]は、この回答を依頼した時点の
  /// アプリ表示言語（'ja'/'en'/'vi'）。AIの回答自体には含まれないため、
  /// 呼び出し側（送信時に使った言語）から渡してもらい、解析成功時に
  /// [PronunciationEvaluation.languageCode]として補う。
  static PronunciationAiParseResult parse(
    String rawResponse, {
    String languageCode = 'ja',
  }) {
    return AiEvaluationResponseParser.parse<PronunciationEvaluation>(
      rawResponse: rawResponse,
      languageCode: languageCode,
      evaluationVersion: evaluationVersion,
      acceptMap: (decoded) => decoded.containsKey('categoryEvaluations'),
      fromJson: PronunciationEvaluation.fromJson,
    );
  }
}
