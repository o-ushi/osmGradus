import 'pronunciation_evaluation.dart';
import 'pronunciation_exercise.dart';
import 'pronunciation_practice_session.dart';

PronunciationQuestionStatus _statusFromName(String? name) {
  if (name == null) return PronunciationQuestionStatus.waiting;
  return PronunciationQuestionStatus.values.firstWhere(
    (status) => status.name == name,
    orElse: () => PronunciationQuestionStatus.waiting,
  );
}

/// 保存された発音チェック結果1件のうち、出題1問分のスナップショット。
///
/// [PronunciationExercise]をまるごと参照せず必要な情報だけを複製するのは、
/// 組み込み課題バンクの内容が将来変わっても、過去に保存した履歴の表示が
/// 壊れないようにするため。
class SavedPronunciationQuestionResult {
  const SavedPronunciationQuestionResult({
    required this.exerciseId,
    required this.category,
    required this.sentence,
    required this.status,
    this.sttResult,
  });

  final String exerciseId;
  final PronunciationCategory category;
  final String sentence;
  final PronunciationQuestionStatus status;

  /// 端末STTによる認識結果。未回答の場合はnull。
  final String? sttResult;

  factory SavedPronunciationQuestionResult.fromJson(Map<String, dynamic> json) {
    return SavedPronunciationQuestionResult(
      exerciseId: json['exerciseId'] as String,
      category: PronunciationCategoryLabel.fromStorageKey(
        json['category'] as String,
      ),
      sentence: json['sentence'] as String? ?? '',
      status: _statusFromName(json['status'] as String?),
      sttResult: json['sttResult'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'category': category.storageKey,
    'sentence': sentence,
    'status': status.name,
    'sttResult': sttResult,
  };
}

/// レイヤーⅤで保存する1件分の発音チェック結果。
///
/// 当初（旧形式）はChrome AIの自由記述な発音診断結果テキスト（[transcript]）
/// のみを保持していた。新形式では10問セッションと5カテゴリの参考評価
/// （[PronunciationEvaluation]、[Chrome AIには録音音声自体は送らず期待文と
/// 端末STT結果の比較に基づく]）も保持できる。[transcript]は旧形式データの
/// 内容を失わないよう常に保持し続ける（新形式では空文字）。
class SavedPronunciationCheck {
  const SavedPronunciationCheck({
    required this.id,
    required this.createdAt,
    required this.transcript,
    this.sessionId,
    this.questions,
    this.evaluation,
    this.unparsedResponse,
    this.source = 'short',
    this.longArticleId,
    this.longArticleTitle,
  });

  final String id;
  final DateTime createdAt;

  /// 旧形式（自由記述のChrome AI貼り付け結果）では自由記述そのもの。
  /// [source]が`'long'`（長文音読）のレコードでは、音読を端末STTで
  /// 文字起こしした結果を保持する（新形式の10問セッションでは空文字）。
  final String transcript;

  /// 新形式（10問セッション／長文音読1件）の識別ID。旧形式データではnull。
  final String? sessionId;

  /// 出題した10問と、各問題のSTT結果・回答状態。旧形式データ・長文音読
  /// （[source] == `'long'`）ではnull。
  final List<SavedPronunciationQuestionResult>? questions;

  /// Chrome AIによる5カテゴリの参考評価（AI回答原文・evaluationVersionを含む）。
  /// 旧形式データ、または新形式で解析に失敗した場合はnull
  /// （後者は[unparsedResponse]に原文が残る）。
  final PronunciationEvaluation? evaluation;

  /// 新形式で評価の解析に失敗した場合の、Chrome AIの回答原文。
  final String? unparsedResponse;

  /// レイヤーⅤの出所。`'short'`＝短文10問（既定、旧データも含む）、
  /// `'long'`＝長文一覧からランダムに選んだ長文の音読（Step 7で追加）。
  final String source;

  /// [source]が`'long'`のときに音読した[LongArticle.id]。
  /// 対象の長文が後で削除されても記録自体は残るため、削除後はnullではなく
  /// 削除前のIDのまま残り続ける（表示は[longArticleTitle]を優先する）。
  final String? longArticleId;

  /// [source]が`'long'`のときに音読した長文のタイトル（保存時点の複製）。
  final String? longArticleTitle;

  /// 新形式（セッション+評価）のデータを持たない旧形式レコードかどうか。
  /// 新形式で解析に失敗した記録（[sessionId]はあるが[evaluation]がnull）は
  /// 旧形式ではない（[unparsedResponse]に原文を保持している）。
  bool get isLegacyFormat => sessionId == null && evaluation == null;

  /// [session]の出題内容と回答状態、[evaluation]から新形式レコードを組み立てる。
  /// 解析に失敗した場合は[evaluation]をnullにし、[unparsedResponse]に原文を渡す。
  factory SavedPronunciationCheck.fromSession({
    required String id,
    required String sessionId,
    required DateTime createdAt,
    required PronunciationPracticeSession session,
    PronunciationEvaluation? evaluation,
    String? unparsedResponse,
  }) {
    return SavedPronunciationCheck(
      id: id,
      createdAt: createdAt,
      transcript: '',
      sessionId: sessionId,
      questions: [
        for (final question in session.questions)
          SavedPronunciationQuestionResult(
            exerciseId: question.exercise.id,
            category: question.exercise.category,
            sentence: question.exercise.sentence,
            status: question.status,
            sttResult: question.sttResult,
          ),
      ],
      evaluation: evaluation,
      unparsedResponse: unparsedResponse,
    );
  }

  /// 長文一覧からランダムに選んだ長文の音読（レイヤーⅤ「長文」）から
  /// 新形式レコードを組み立てる。[questions]は持たない（10問の枠組みが
  /// そもそも当てはまらないため）。解析に失敗した場合は[evaluation]をnullにし、
  /// [unparsedResponse]に原文を渡す。
  factory SavedPronunciationCheck.fromLongReading({
    required String id,
    required String sessionId,
    required DateTime createdAt,
    required String articleId,
    required String articleTitle,
    required String transcript,
    PronunciationEvaluation? evaluation,
    String? unparsedResponse,
  }) {
    return SavedPronunciationCheck(
      id: id,
      createdAt: createdAt,
      transcript: transcript,
      sessionId: sessionId,
      questions: null,
      evaluation: evaluation,
      unparsedResponse: unparsedResponse,
      source: 'long',
      longArticleId: articleId,
      longArticleTitle: articleTitle,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'transcript': transcript,
    if (sessionId != null) 'sessionId': sessionId,
    if (questions != null)
      'questions': questions!.map((q) => q.toJson()).toList(),
    if (evaluation != null) 'evaluation': evaluation!.toJson(),
    if (unparsedResponse != null) 'unparsedResponse': unparsedResponse,
    if (source != 'short') 'source': source,
    if (longArticleId != null) 'longArticleId': longArticleId,
    if (longArticleTitle != null) 'longArticleTitle': longArticleTitle,
  };

  factory SavedPronunciationCheck.fromJson(Map<String, dynamic> json) {
    return SavedPronunciationCheck(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      transcript: json['transcript'] as String? ?? '',
      sessionId: json['sessionId'] as String?,
      questions: _parseQuestions(json['questions']),
      evaluation: _parseEvaluation(json['evaluation']),
      unparsedResponse: json['unparsedResponse'] as String?,
      source: json['source'] as String? ?? 'short',
      longArticleId: json['longArticleId'] as String?,
      longArticleTitle: json['longArticleTitle'] as String?,
    );
  }

  static List<SavedPronunciationQuestionResult>? _parseQuestions(Object? raw) {
    if (raw is! List) return null;
    final results = <SavedPronunciationQuestionResult>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        results.add(
          SavedPronunciationQuestionResult.fromJson(
            Map<String, dynamic>.from(item),
          ),
        );
      } catch (_) {
        // 破損した1問分だけを読み飛ばし、他の問題やレコード全体の
        // 読み込みは継続する。
      }
    }
    return results;
  }

  static PronunciationEvaluation? _parseEvaluation(Object? raw) {
    if (raw is! Map) return null;
    try {
      return PronunciationEvaluation.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      // 評価データが壊れていても、id/createdAt/transcript/questionsの
      // 読み込みは継続する。
      return null;
    }
  }
}
