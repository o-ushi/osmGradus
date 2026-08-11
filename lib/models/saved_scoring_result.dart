import '../models/scoring_models.dart';

/// レイヤーⅣで保存する1件分の採点結果。
/// osmWashabeは採点結果を永続化しない（直近5件のインメモリ履歴のみ）が、
/// osmGradusでは件数上限なしでローカルに保存する。
/// 音声ファイルは保存しない（録音は毎回同じファイル名で上書きされるため、
/// 過去の結果にパスを持たせても後から別録音を指してしまう上、そもそも
/// ファイルを全件分保持するとストレージを圧迫するため）。
///
/// [result]（JSST採点）はローカル解析のみで完結するが、[prepStars]・
/// [hitStars]（PREP・的中度）はChrome AIへの評価依頼が必要なため、
/// 採点直後は未設定（null）で保存し、ユーザーが「送信」した後に
/// [ScoringResultStorage.update]で同じレコードへ書き足す（Step 8）。
class SavedScoringResult {
  const SavedScoringResult({
    required this.id,
    required this.createdAt,
    required this.result,
    this.prepStars,
    this.hitStars,
    this.prepAdvice,
    this.hitAdvice,
    this.aiEvaluationUnparsedResponse,
    this.questionPromptId,
    this.questionPromptBody,
  });

  final String id;
  final DateTime createdAt;
  final ScoringResult result;

  /// レイヤーⅣ「問題文一覧から選ぶ」（[Layer4Screen.fixedPrompt]）経由で
  /// 採点した場合の対象[QuestionPrompt.id]。「ランダム」経由（抽選のお題）は
  /// 問題文エンティティに紐付かないためnull。対象の問題文が後で削除されても
  /// 記録自体は残るため、削除後もnullに戻さず削除前のIDのまま残り続ける。
  final String? questionPromptId;

  /// [questionPromptId]が非nullのときの問題文本文（保存時点の複製）。
  final String? questionPromptBody;

  /// Chrome AIによる「結論→理由→例」（PREP）の型への一致度、1〜5点。
  /// 未送信・旧データ（Step 8以前）ではnull。
  final int? prepStars;

  /// Chrome AIによる的中度（質問への的確さ）、1〜5点。
  /// 未送信・旧データ（Step 8以前）ではnull。
  final int? hitStars;

  /// PREPへの一言アドバイス。AIが返さなかった場合はnull。
  final String? prepAdvice;

  /// 的中度への一言アドバイス。AIが返さなかった場合はnull。
  final String? hitAdvice;

  /// PREP・的中度の評価解析に失敗した場合の、Chrome AIの回答原文。
  final String? aiEvaluationUnparsedResponse;

  /// PREP・的中度のAI評価を持つか（旧データ・未送信ではfalse）。
  bool get hasAiEvaluation => prepStars != null && hitStars != null;

  /// PREP・的中度の評価結果を反映した新しいレコードを返す
  /// （[ScoringResultStorage.update]で永続化する）。解析失敗時は
  /// [prepStars]・[hitStars]・アドバイスを渡さず、
  /// [aiEvaluationUnparsedResponse]だけ渡す。
  SavedScoringResult withAiEvaluation({
    int? prepStars,
    int? hitStars,
    String? prepAdvice,
    String? hitAdvice,
    String? aiEvaluationUnparsedResponse,
  }) => SavedScoringResult(
    id: id,
    createdAt: createdAt,
    result: result,
    prepStars: prepStars,
    hitStars: hitStars,
    prepAdvice: prepAdvice,
    hitAdvice: hitAdvice,
    aiEvaluationUnparsedResponse: aiEvaluationUnparsedResponse,
    questionPromptId: questionPromptId,
    questionPromptBody: questionPromptBody,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'fullTranscript': result.fullTranscript,
    'transcriptChunks': result.transcriptChunks
        .map(
          (c) => {
            'text': c.text,
            'recognizedAt': c.recognizedAt.toIso8601String(),
          },
        )
        .toList(),
    'keigo': {
      'varietyScore': result.keigo.varietyScore,
      'categories': result.keigo.categories
          .map(
            (c) => {
              'category': c.category,
              'matchedExpressions': c.matchedExpressions.toList(),
            },
          )
          .toList(),
    },
    'complexity': {
      'totalUnits': result.complexity.totalUnits,
      'complexUnitCount': result.complexity.complexUnitCount,
      'complexityRatio': result.complexity.complexityRatio,
    },
    'fluency': {
      'allottedSeconds': result.fluency.allottedSeconds,
      'capturedSeconds': result.fluency.capturedSeconds,
      'timeToFirstSpeechSeconds': result.fluency.timeToFirstSpeechSeconds,
      'estimatedSpeechSeconds': result.fluency.estimatedSpeechSeconds,
      'estimatedSilenceSeconds': result.fluency.estimatedSilenceSeconds,
      'silenceRatio': result.fluency.silenceRatio,
      'timeUtilization': result.fluency.timeUtilization,
      'spokenCharacterCount': result.fluency.spokenCharacterCount,
      'charactersPerAllottedMinute': result.fluency.charactersPerAllottedMinute,
      'longPauseCount': result.fluency.longPauseCount,
      'referenceLevel': result.fluency.referenceLevel,
    },
    'session': result.session == null
        ? null
        : {
            'allottedSeconds': result.session!.allottedSeconds,
            'startedAt': result.session!.startedAt?.toIso8601String(),
            'endedAt': result.session!.endedAt?.toIso8601String(),
          },
    if (prepStars != null) 'prepStars': prepStars,
    if (hitStars != null) 'hitStars': hitStars,
    if (prepAdvice != null) 'prepAdvice': prepAdvice,
    if (hitAdvice != null) 'hitAdvice': hitAdvice,
    if (aiEvaluationUnparsedResponse != null)
      'aiEvaluationUnparsedResponse': aiEvaluationUnparsedResponse,
    if (questionPromptId != null) 'questionPromptId': questionPromptId,
    if (questionPromptBody != null) 'questionPromptBody': questionPromptBody,
  };

  factory SavedScoringResult.fromJson(Map<String, dynamic> json) {
    final chunksJson = json['transcriptChunks'] as List<dynamic>? ?? [];
    final chunks = chunksJson
        .map(
          (raw) => TranscriptChunk(
            text: (raw as Map<String, dynamic>)['text'] as String,
            recognizedAt: DateTime.parse(raw['recognizedAt'] as String),
          ),
        )
        .toList();

    final keigoJson = json['keigo'] as Map<String, dynamic>;
    final categoriesJson = keigoJson['categories'] as List<dynamic>;
    final keigo = KeigoAnalysis(
      categories: categoriesJson
          .map(
            (raw) => KeigoCategoryResult(
              category: (raw as Map<String, dynamic>)['category'] as String,
              matchedExpressions: Set<String>.from(
                raw['matchedExpressions'] as List<dynamic>,
              ),
            ),
          )
          .toList(),
      varietyScore: keigoJson['varietyScore'] as int,
    );

    final complexityJson = json['complexity'] as Map<String, dynamic>;
    final complexity = SentenceComplexityAnalysis(
      totalUnits: complexityJson['totalUnits'] as int,
      complexUnitCount: complexityJson['complexUnitCount'] as int,
      complexityRatio: (complexityJson['complexityRatio'] as num).toDouble(),
    );

    final fluencyJson = json['fluency'] as Map<String, dynamic>;
    final fluency = FluencyAnalysis(
      allottedSeconds: fluencyJson['allottedSeconds'] as int,
      capturedSeconds: (fluencyJson['capturedSeconds'] as num).toDouble(),
      timeToFirstSpeechSeconds: (fluencyJson['timeToFirstSpeechSeconds'] as num)
          .toDouble(),
      estimatedSpeechSeconds: (fluencyJson['estimatedSpeechSeconds'] as num)
          .toDouble(),
      estimatedSilenceSeconds: (fluencyJson['estimatedSilenceSeconds'] as num)
          .toDouble(),
      silenceRatio: (fluencyJson['silenceRatio'] as num).toDouble(),
      timeUtilization: (fluencyJson['timeUtilization'] as num).toDouble(),
      spokenCharacterCount: fluencyJson['spokenCharacterCount'] as int,
      charactersPerAllottedMinute:
          (fluencyJson['charactersPerAllottedMinute'] as num).toDouble(),
      longPauseCount: fluencyJson['longPauseCount'] as int,
      referenceLevel: fluencyJson['referenceLevel'] as int,
    );

    final sessionJson = json['session'] as Map<String, dynamic>?;
    final session = sessionJson == null
        ? null
        : SpeechSessionContext(
            allottedSeconds: sessionJson['allottedSeconds'] as int,
            startedAt: sessionJson['startedAt'] == null
                ? null
                : DateTime.parse(sessionJson['startedAt'] as String),
            endedAt: sessionJson['endedAt'] == null
                ? null
                : DateTime.parse(sessionJson['endedAt'] as String),
          );

    final createdAt = DateTime.parse(json['createdAt'] as String);
    return SavedScoringResult(
      id: json['id'] as String,
      createdAt: createdAt,
      result: ScoringResult(
        transcriptChunks: chunks,
        fullTranscript: json['fullTranscript'] as String,
        keigo: keigo,
        complexity: complexity,
        fluency: fluency,
        session: session,
        generatedAt: createdAt,
      ),
      prepStars: (json['prepStars'] as num?)?.toInt(),
      hitStars: (json['hitStars'] as num?)?.toInt(),
      prepAdvice: json['prepAdvice'] as String?,
      hitAdvice: json['hitAdvice'] as String?,
      aiEvaluationUnparsedResponse:
          json['aiEvaluationUnparsedResponse'] as String?,
      questionPromptId: json['questionPromptId'] as String?,
      questionPromptBody: json['questionPromptBody'] as String?,
    );
  }
}
