/// 単語テスト1問に対するChrome AIの参考評価。
class VocabularyQuestionEvaluation {
  const VocabularyQuestionEvaluation({required this.correct, this.feedback});

  /// 学習者の回答（STT結果）が正解の単語の訳として妥当だったか。
  final bool correct;

  /// 短いフィードバック（正解の補足や、惜しかった点の指摘など）。
  final String? feedback;

  factory VocabularyQuestionEvaluation.fromJson(Map<String, dynamic> json) =>
      VocabularyQuestionEvaluation(
        correct: json['correct'] == true,
        feedback: json['feedback'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'correct': correct,
    if (feedback != null) 'feedback': feedback,
  };
}

/// レイヤーⅠ単語テストセッション全体に対するChrome AIの参考評価。
///
/// レイヤーⅤ（[PronunciationEvaluation]）と異なり、語彙テストには
/// 「つ／ざ行／ラ行」のような固定カテゴリが無いため、カテゴリ別ではなく
/// 総合1〜5点＋各問の正誤という単純な形にしている。
class VocabularyEvaluation {
  const VocabularyEvaluation({
    required int overallScore,
    this.summary,
    required this.questionEvaluations,
    this.languageCode = 'ja',
    required this.rawResponse,
    required this.evaluationVersion,
  }) : overallScore = overallScore < 1
           ? 1
           : (overallScore > 5 ? 5 : overallScore);

  /// 1〜5の総合参考評価スコア。範囲外の値は1〜5に補正される。
  final int overallScore;

  /// 評価取得時のアプリ表示言語で書かれた全体講評。
  final String? summary;

  /// 出題順と対応する、各問の正誤・フィードバック。
  final List<VocabularyQuestionEvaluation> questionEvaluations;

  /// この評価をChrome AIへ依頼した時点のアプリ表示言語（'ja'/'en'/'vi'）。
  final String languageCode;

  /// Chrome AIから返された元のレスポンス文字列（デバッグ・監査用）。
  final String rawResponse;

  /// 評価スキーマのバージョン。互換性のない形式変更時にインクリメントする。
  final String evaluationVersion;

  /// 「★★★☆☆」形式の総合スコア表示。
  String get starDisplay => '★' * overallScore + '☆' * (5 - overallScore);

  /// 正解した問題数。
  int get correctCount => questionEvaluations.where((q) => q.correct).length;

  /// 1秒チェックの機械採点を、Chrome AIの単語評価の先頭に付け足す。
  /// クイズはAIに送らない。[overallScore]はクイズ＋単語の正解率から再計算する。
  VocabularyEvaluation aligningComprehensionQuiz({
    required bool isCorrect,
    required int vocabQuestionCount,
    String? feedback,
  }) {
    final quizEval = VocabularyQuestionEvaluation(
      correct: isCorrect,
      feedback: feedback,
    );
    final rest = questionEvaluations;
    final List<VocabularyQuestionEvaluation> aligned;
    if (rest.length == vocabQuestionCount + 1) {
      aligned = [
        VocabularyQuestionEvaluation(
          correct: isCorrect,
          feedback: feedback ?? rest.first.feedback,
        ),
        ...rest.skip(1),
      ];
    } else if (rest.length >= vocabQuestionCount) {
      aligned = [quizEval, ...rest.take(vocabQuestionCount)];
    } else {
      aligned = [quizEval, ...rest];
    }
    return VocabularyEvaluation(
      overallScore: starsFromCorrectRatio(aligned),
      summary: summary,
      questionEvaluations: aligned,
      languageCode: languageCode,
      rawResponse: rawResponse,
      evaluationVersion: evaluationVersion,
    );
  }

  /// 正解率を1〜5の★に写す（0%→1、100%→5。四捨五入）。
  static int starsFromCorrectRatio(List<VocabularyQuestionEvaluation> items) {
    if (items.isEmpty) return 1;
    final ratio = items.where((q) => q.correct).length / items.length;
    final stars = (ratio * 5).round();
    return stars < 1 ? 1 : (stars > 5 ? 5 : stars);
  }

  factory VocabularyEvaluation.fromJson(Map<String, dynamic> json) {
    final rawQuestions = json['questionEvaluations'] as List<dynamic>? ?? [];
    return VocabularyEvaluation(
      overallScore: (json['overallScore'] as num).toInt(),
      summary: json['summary'] as String?,
      questionEvaluations: [
        for (final item in rawQuestions)
          VocabularyQuestionEvaluation.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
      ],
      languageCode: json['languageCode'] as String? ?? 'ja',
      rawResponse: json['rawResponse'] as String,
      evaluationVersion: json['evaluationVersion'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'overallScore': overallScore,
    if (summary != null) 'summary': summary,
    'questionEvaluations': [for (final q in questionEvaluations) q.toJson()],
    'languageCode': languageCode,
    'rawResponse': rawResponse,
    'evaluationVersion': evaluationVersion,
  };
}
