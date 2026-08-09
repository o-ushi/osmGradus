/// レイヤーⅤ発音評価（短文10問・長文音読）で共通のChrome AI出力JSONスキーマ。
///
/// [PronunciationAiPromptTemplate]と[LongReadingAiPromptTemplate]の両方から
/// 参照し、スキーマ文言のドリフトを防ぐ。[PronunciationAiResponseParser] /
/// [PronunciationEvaluation.fromJson]がそのまま読める形。
abstract final class PronunciationAiJsonSchema {
  /// `categoryEvaluations`/`summary`の固定出力形式。
  /// `feedback`・`summary`の言語は各プロンプトの指示に従う。
  /// `rawResponse`・`evaluationVersion`・`languageCode`はAIには依頼せず、
  /// 貼り付け後にアプリ側で補う。
  static const template = '''
{
  "categoryEvaluations": {
    "tsu": {"score": 1〜5の整数, "confidence": "low"|"medium"|"high", "feedback": "フィードバック文", "evidence": "評価の根拠"},
    "zRow": {"score": 1〜5の整数, "confidence": "low"|"medium"|"high", "feedback": "...", "evidence": "..."},
    "rRow": {"score": 1〜5の整数, "confidence": "low"|"medium"|"high", "feedback": "...", "evidence": "..."},
    "longVowel": {"score": 1〜5の整数, "confidence": "low"|"medium"|"high", "feedback": "...", "evidence": "..."},
    "sokuon": {"score": 1〜5の整数, "confidence": "low"|"medium"|"high", "feedback": "...", "evidence": "..."}
  },
  "summary": "全体講評"
}''';
}
