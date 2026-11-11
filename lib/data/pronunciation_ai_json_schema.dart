/// レイヤーⅤ発音評価（短文10問・長文音読）で共通のChrome AI出力JSONスキーマ。
///
/// [PronunciationAiPromptTemplate]と[LongReadingAiPromptTemplate]の両方から
/// 参照し、スキーマ文言のドリフトを防ぐ。[PronunciationAiResponseParser] /
/// [PronunciationEvaluation.fromJson]がそのまま読める形。
abstract final class PronunciationAiJsonSchema {
  /// `categoryEvaluations`/`overallEvaluations`/`summary`の固定出力形式。
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
  "overallEvaluations": {"rhythm": {...}, "omission": {...}},
  "summary": "全体講評"
}''';

  /// `overallEvaluations`（5カテゴリとは別枠の、発話全体にかかる癖）の
  /// 評価観点の説明。全発音プロンプトで共有する。URLプリフィルの長さ
  /// （長文音読など）を圧迫しないよう短く保つこと。
  static String overallNote(String lang) => switch (lang) {
    'en' =>
      'overallEvaluations rates the whole utterance separately from the 5 '
          'categories: rhythm = each mora clipped/choppy, sokuon-like '
          '(e.g. わたし→わったし); omission = dropped sounds '
          '(e.g. お願いします→お願います). If the transcript cannot show it, '
          'set confidence to low.',
    'vi' =>
      'overallEvaluations đánh giá toàn bộ lời nói, tách biệt với 5 nhóm: '
          'rhythm = từng âm bị ngắt quãng, nghe như âm ngắt (vd. わたし→わったし); '
          'omission = rơi âm (vd. お願いします→お願います). Nếu bản ghi không '
          'thể hiện được, đặt confidence là low.',
    _ =>
      'overallEvaluationsは発話全体を評価: rhythm=一音ずつ区切れ促音気味か, '
          'omission=音の欠落(お願います等)。判断できなければconfidence=low。',
  };
}
