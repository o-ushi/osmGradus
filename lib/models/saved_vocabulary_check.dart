import 'vocab_test_session.dart';
import 'vocabulary_evaluation.dart';

VocabTestQuestionStatus _statusFromName(String? name) {
  if (name == null) return VocabTestQuestionStatus.waiting;
  return VocabTestQuestionStatus.values.firstWhere(
    (status) => status.name == name,
    orElse: () => VocabTestQuestionStatus.waiting,
  );
}

/// 保存された単語テスト結果1件のうち、出題1問分のスナップショット。
///
/// 単語帳の該当エントリを参照せず必要な情報だけを複製するのは、単語帳側の
/// 内容（編集・削除）が変わっても、過去に保存した履歴の表示が壊れないように
/// するため（[SavedPronunciationQuestionResult]と同じ考え方）。
class SavedVocabQuestionResult {
  const SavedVocabQuestionResult({
    required this.word,
    required this.reading,
    required this.translation,
    required this.status,
    this.sttResult,
  });

  final String word;
  final String reading;
  final String translation;
  final VocabTestQuestionStatus status;

  /// 端末STTによる認識結果。未回答の場合はnull。
  final String? sttResult;

  factory SavedVocabQuestionResult.fromJson(Map<String, dynamic> json) {
    return SavedVocabQuestionResult(
      word: json['word'] as String,
      reading: json['reading'] as String? ?? '',
      translation: json['translation'] as String? ?? '',
      status: _statusFromName(json['status'] as String?),
      sttResult: json['sttResult'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'word': word,
    'reading': reading,
    'translation': translation,
    'status': status.name,
    'sttResult': sttResult,
  };
}

/// 長文読解の1秒チェック（2択クイズ）1問分のスナップショット。
/// 語彙テスト結果と一緒に[SavedVocabularyCheck]へ載せ、一覧・詳細の母数を
/// 「クイズ1＋単語最大9＝最大10」にするためのもの。
class SavedComprehensionQuizResult {
  const SavedComprehensionQuizResult({
    required this.question,
    required this.optionA,
    required this.optionB,
    required this.correctOption,
    required this.selectedOption,
    required this.isCorrect,
    this.explanationJa = '',
    this.explanationEn = '',
    this.explanationVi = '',
  });

  final String question;
  final String optionA;
  final String optionB;
  final String correctOption;
  final String selectedOption;
  final bool isCorrect;
  final String explanationJa;
  final String explanationEn;
  final String explanationVi;

  String explanationFor(String languageCode) => switch (languageCode) {
    'en' => explanationEn.isNotEmpty ? explanationEn : explanationJa,
    'vi' => explanationVi.isNotEmpty ? explanationVi : explanationJa,
    _ => explanationJa,
  };

  Map<String, dynamic> toJson() => {
    'question': question,
    'optionA': optionA,
    'optionB': optionB,
    'correctOption': correctOption,
    'selectedOption': selectedOption,
    'isCorrect': isCorrect,
    if (explanationJa.isNotEmpty) 'explanationJa': explanationJa,
    if (explanationEn.isNotEmpty) 'explanationEn': explanationEn,
    if (explanationVi.isNotEmpty) 'explanationVi': explanationVi,
  };

  factory SavedComprehensionQuizResult.fromJson(Map<String, dynamic> json) =>
      SavedComprehensionQuizResult(
        question: json['question'] as String? ?? '',
        optionA: json['optionA'] as String? ?? '',
        optionB: json['optionB'] as String? ?? '',
        correctOption: json['correctOption'] as String? ?? '',
        selectedOption: json['selectedOption'] as String? ?? '',
        isCorrect: json['isCorrect'] == true,
        explanationJa: json['explanationJa'] as String? ?? '',
        explanationEn: json['explanationEn'] as String? ?? '',
        explanationVi: json['explanationVi'] as String? ?? '',
      );
}

/// レイヤーⅠ単語テストで保存する1件分の結果。
class SavedVocabularyCheck {
  const SavedVocabularyCheck({
    required this.id,
    required this.createdAt,
    required this.sessionId,
    required this.questions,
    this.evaluation,
    this.unparsedResponse,
    this.questionPromptId,
    this.questionPromptBody,
    this.longArticleId,
    this.longArticleTitle,
    this.comprehensionQuiz,
  });

  final String id;
  final DateTime createdAt;
  final String sessionId;

  /// 出題した語と、各問題のSTT結果・回答状態。
  final List<SavedVocabQuestionResult> questions;

  /// Chrome AIによる参考評価（AI回答原文・evaluationVersionを含む）。
  /// 解析に失敗した場合はnull（[unparsedResponse]に原文が残る）。
  final VocabularyEvaluation? evaluation;

  /// 評価の解析に失敗した場合の、Chrome AIの回答原文。
  final String? unparsedResponse;

  /// 総評画面の「分からなかった単語だけテスト」（[Layer1VocabScreen.fixedEntries]）
  /// 経由で実施した場合の対象[QuestionPrompt.id]（[SavedScoringResult.questionPromptId]
  /// と同じ考え方）。通常の（プールから抽選する）単語テストはnull。対象の
  /// 問題文が後で削除されても記録自体は残るため、削除後もnullに戻さない。
  final String? questionPromptId;

  /// [questionPromptId]が非nullのときの問題文本文（保存時点の複製）。
  final String? questionPromptBody;

  /// レイヤーⅠ「長文読解」の語彙テスト（[Layer1VocabScreen.gradedLongArticle]）
  /// 経由で実施した場合の対象[LongArticle.id]（[questionPromptId]と同じ考え方）。
  /// 通常の（プールから抽選する）単語テストと問題文経由はnull。対象の長文が
  /// 後で削除されても記録自体は残るため、削除後もnullに戻さない。
  final String? longArticleId;

  /// [longArticleId]が非nullのときの長文タイトル（保存時点の複製）。
  final String? longArticleTitle;

  /// 長文読解フローで1秒チェックを実施した場合の結果。通常の単語テスト・
  /// 問題文経由ではnull。Chrome AIの単語評価へ後から1問目として付け足す。
  final SavedComprehensionQuizResult? comprehensionQuiz;

  /// 単語の[questions]に対する[evaluation.questionEvaluations]の開始位置。
  /// クイズを1問目として評価配列に含めた新記録は1、旧記録（単語だけ）は0。
  int get vocabEvaluationOffset {
    final evaluation = this.evaluation;
    final quiz = comprehensionQuiz;
    if (evaluation == null || quiz == null) return 0;
    if (evaluation.questionEvaluations.length == questions.length + 1) {
      return 1;
    }
    return 0;
  }

  /// 単語[wordIndex]に対応するAI評価（クイズが1問目のときは+1して読む）。
  VocabularyQuestionEvaluation? vocabQuestionEvaluationAt(int wordIndex) {
    final evaluation = this.evaluation;
    if (evaluation == null) return null;
    final evalIndex = wordIndex + vocabEvaluationOffset;
    if (evalIndex >= evaluation.questionEvaluations.length) return null;
    return evaluation.questionEvaluations[evalIndex];
  }

  /// 一覧・詳細に出す出題数（単語＋クイズがあれば1）。
  int get combinedQuestionCount =>
      questions.length + (comprehensionQuiz != null ? 1 : 0);

  /// 一覧・詳細に出す正解数。新記録は[evaluation]がクイズを1問目に含むので
  /// その[correctCount]を使う。旧記録（評価が単語だけ）はクイズ分を足す。
  int get combinedCorrectCount {
    final quiz = comprehensionQuiz;
    final evaluation = this.evaluation;
    if (evaluation == null) {
      return quiz?.isCorrect == true ? 1 : 0;
    }
    if (quiz == null || vocabEvaluationOffset == 1) {
      return evaluation.correctCount;
    }
    return evaluation.correctCount + (quiz.isCorrect ? 1 : 0);
  }

  /// [session]の出題内容と回答状態、[evaluation]から1件分のレコードを
  /// 組み立てる。解析に失敗した場合は[unparsedResponse]に原文を渡す。
  factory SavedVocabularyCheck.fromSession({
    required String id,
    required String sessionId,
    required DateTime createdAt,
    required VocabTestSession session,
    VocabularyEvaluation? evaluation,
    String? unparsedResponse,
    String? questionPromptId,
    String? questionPromptBody,
    String? longArticleId,
    String? longArticleTitle,
    SavedComprehensionQuizResult? comprehensionQuiz,
  }) {
    return SavedVocabularyCheck(
      id: id,
      createdAt: createdAt,
      sessionId: sessionId,
      questions: [
        for (final question in session.questions)
          SavedVocabQuestionResult(
            word: question.entry.word,
            reading: question.entry.reading,
            translation: question.entry.translation,
            status: question.status,
            sttResult: question.sttResult,
          ),
      ],
      evaluation: evaluation,
      unparsedResponse: unparsedResponse,
      questionPromptId: questionPromptId,
      questionPromptBody: questionPromptBody,
      longArticleId: longArticleId,
      longArticleTitle: longArticleTitle,
      comprehensionQuiz: comprehensionQuiz,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'sessionId': sessionId,
    'questions': questions.map((q) => q.toJson()).toList(),
    if (evaluation != null) 'evaluation': evaluation!.toJson(),
    if (unparsedResponse != null) 'unparsedResponse': unparsedResponse,
    if (questionPromptId != null) 'questionPromptId': questionPromptId,
    if (questionPromptBody != null) 'questionPromptBody': questionPromptBody,
    if (longArticleId != null) 'longArticleId': longArticleId,
    if (longArticleTitle != null) 'longArticleTitle': longArticleTitle,
    if (comprehensionQuiz != null)
      'comprehensionQuiz': comprehensionQuiz!.toJson(),
  };

  factory SavedVocabularyCheck.fromJson(Map<String, dynamic> json) {
    return SavedVocabularyCheck(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      sessionId: json['sessionId'] as String? ?? '',
      questions: _parseQuestions(json['questions']),
      evaluation: _parseEvaluation(json['evaluation']),
      unparsedResponse: json['unparsedResponse'] as String?,
      questionPromptId: json['questionPromptId'] as String?,
      questionPromptBody: json['questionPromptBody'] as String?,
      longArticleId: json['longArticleId'] as String?,
      longArticleTitle: json['longArticleTitle'] as String?,
      comprehensionQuiz: json['comprehensionQuiz'] is Map
          ? SavedComprehensionQuizResult.fromJson(
              Map<String, dynamic>.from(json['comprehensionQuiz'] as Map),
            )
          : null,
    );
  }

  static List<SavedVocabQuestionResult> _parseQuestions(Object? raw) {
    if (raw is! List) return const [];
    final results = <SavedVocabQuestionResult>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        results.add(
          SavedVocabQuestionResult.fromJson(Map<String, dynamic>.from(item)),
        );
      } catch (_) {
        // 破損した1問分だけを読み飛ばし、他の問題やレコード全体の
        // 読み込みは継続する。
      }
    }
    return results;
  }

  static VocabularyEvaluation? _parseEvaluation(Object? raw) {
    if (raw is! Map) return null;
    try {
      return VocabularyEvaluation.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      // 評価データが壊れていても、id/createdAt/questionsの読み込みは継続する。
      return null;
    }
  }
}
