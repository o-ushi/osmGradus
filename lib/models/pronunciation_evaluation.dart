import 'pronunciation_exercise.dart';

/// Chrome AI評価の確からしさの目安。
///
/// 録音音声そのものはChrome AIへ送られず、期待文と端末STT結果の文字列比較を
/// 元に評価するため、この評価全体は音響的な正誤を断定しない「参考評価」である。
enum PronunciationConfidence { low, medium, high }

extension PronunciationConfidenceLabel on PronunciationConfidence {
  String get storageKey => switch (this) {
    PronunciationConfidence.low => 'low',
    PronunciationConfidence.medium => 'medium',
    PronunciationConfidence.high => 'high',
  };

  /// 不明な値はlow（最も慎重な扱い）にフォールバックする。
  static PronunciationConfidence fromStorageKey(String key) =>
      PronunciationConfidence.values.firstWhere(
        (confidence) => confidence.storageKey == key,
        orElse: () => PronunciationConfidence.low,
      );
}

/// 1カテゴリ分のChrome AI参考評価。
class PronunciationCategoryEvaluation {
  PronunciationCategoryEvaluation({
    required int score,
    required this.confidence,
    this.feedback,
    this.feedbackJa,
    this.feedbackVi,
    required this.evidence,
  }) : score = _clampScore(score);

  /// 1〜5の参考評価スコア。範囲外の値は1〜5に補正される。
  final int score;
  final PronunciationConfidence confidence;

  /// 評価取得時のアプリ表示言語で書かれた単一言語のフィードバック文
  /// （evaluationVersion `v2`以降のスキーマ）。
  final String? feedback;

  /// 旧形式（`v1`）互換用：日本語のフィードバック文。
  /// `v1`は常に[feedbackJa]・[feedbackVi]の両方を保持していたため、
  /// 表示側はこれらが揃っている場合、[feedback]がなくても両方併記する。
  final String? feedbackJa;

  /// 旧形式（`v1`）互換用：ベトナム語のフィードバック文。
  final String? feedbackVi;

  /// 評価の根拠（期待文と端末STT結果の比較箇所など）。
  final String evidence;

  static int _clampScore(int score) => score.clamp(1, 5);

  /// 「★★★★☆」形式のスコア表示。
  String get starDisplay => '★' * score + '☆' * (5 - score);

  factory PronunciationCategoryEvaluation.fromJson(Map<String, dynamic> json) {
    return PronunciationCategoryEvaluation(
      score: (json['score'] as num).toInt(),
      confidence: PronunciationConfidenceLabel.fromStorageKey(
        json['confidence'] as String,
      ),
      feedback: json['feedback'] as String?,
      feedbackJa: json['feedbackJa'] as String?,
      feedbackVi: json['feedbackVi'] as String?,
      evidence: json['evidence'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'score': score,
    'confidence': confidence.storageKey,
    if (feedback != null) 'feedback': feedback,
    if (feedbackJa != null) 'feedbackJa': feedbackJa,
    if (feedbackVi != null) 'feedbackVi': feedbackVi,
    'evidence': evidence,
  };
}

/// レイヤーⅤ発音練習セッション全体に対するChrome AIの参考評価。
///
/// 録音音声そのものはChrome AIへ送られず、期待文と端末STT結果の比較に基づくため、
/// 音響的な正誤を断定しない「参考評価」として扱う。
class PronunciationEvaluation {
  PronunciationEvaluation({
    required this.categoryEvaluations,
    this.summary,
    this.summaryJa,
    this.summaryVi,
    this.languageCode = 'ja',
    required this.rawResponse,
    required this.evaluationVersion,
  });

  final Map<PronunciationCategory, PronunciationCategoryEvaluation>
  categoryEvaluations;

  /// 評価取得時のアプリ表示言語で書かれた単一言語の全体講評
  /// （evaluationVersion `v2`以降のスキーマ）。
  final String? summary;

  /// 旧形式（`v1`）互換用：日本語の全体講評。
  final String? summaryJa;

  /// 旧形式（`v1`）互換用：ベトナム語の全体講評。
  final String? summaryVi;

  /// この評価をChrome AIへ依頼した時点のアプリ表示言語（'ja'/'en'/'vi'）。
  /// `v1`データにはこの情報がないため、既定は'ja'として扱う。
  final String languageCode;

  /// Chrome AIから返された元のレスポンス文字列（デバッグ・監査用）。
  final String rawResponse;

  /// 評価スキーマのバージョン。互換性のない形式変更時にインクリメントする。
  final String evaluationVersion;

  /// 表示用の全体講評を1つ選ぶ。[summary]（新形式）があればそれを、
  /// なければ[languageCode]に応じて[summaryJa]/[summaryVi]から選ぶ
  /// （旧形式の互換用。どちらも無ければ空文字）。
  String displaySummary(String languageCode) {
    final single = summary?.trim();
    if (single != null && single.isNotEmpty) return single;
    if (languageCode == 'vi') return summaryVi ?? summaryJa ?? '';
    return summaryJa ?? summaryVi ?? '';
  }

  factory PronunciationEvaluation.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['categoryEvaluations'] as Map<String, dynamic>;
    return PronunciationEvaluation(
      categoryEvaluations: {
        for (final entry in rawCategories.entries)
          PronunciationCategoryLabel.fromStorageKey(entry.key):
              PronunciationCategoryEvaluation.fromJson(
                entry.value as Map<String, dynamic>,
              ),
      },
      summary: json['summary'] as String?,
      summaryJa: json['summaryJa'] as String?,
      summaryVi: json['summaryVi'] as String?,
      languageCode: json['languageCode'] as String? ?? 'ja',
      rawResponse: json['rawResponse'] as String,
      evaluationVersion: json['evaluationVersion'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'categoryEvaluations': {
      for (final entry in categoryEvaluations.entries)
        entry.key.storageKey: entry.value.toJson(),
    },
    if (summary != null) 'summary': summary,
    if (summaryJa != null) 'summaryJa': summaryJa,
    if (summaryVi != null) 'summaryVi': summaryVi,
    'languageCode': languageCode,
    'rawResponse': rawResponse,
    'evaluationVersion': evaluationVersion,
  };
}
