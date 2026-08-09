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

/// レイヤーⅠ単語テストで保存する1件分の結果。
class SavedVocabularyCheck {
  const SavedVocabularyCheck({
    required this.id,
    required this.createdAt,
    required this.sessionId,
    required this.questions,
    this.evaluation,
    this.unparsedResponse,
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

  /// [session]の出題内容と回答状態、[evaluation]から1件分のレコードを
  /// 組み立てる。解析に失敗した場合は[unparsedResponse]に原文を渡す。
  factory SavedVocabularyCheck.fromSession({
    required String id,
    required String sessionId,
    required DateTime createdAt,
    required VocabTestSession session,
    VocabularyEvaluation? evaluation,
    String? unparsedResponse,
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
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'sessionId': sessionId,
    'questions': questions.map((q) => q.toJson()).toList(),
    if (evaluation != null) 'evaluation': evaluation!.toJson(),
    if (unparsedResponse != null) 'unparsedResponse': unparsedResponse,
  };

  factory SavedVocabularyCheck.fromJson(Map<String, dynamic> json) {
    return SavedVocabularyCheck(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      sessionId: json['sessionId'] as String? ?? '',
      questions: _parseQuestions(json['questions']),
      evaluation: _parseEvaluation(json['evaluation']),
      unparsedResponse: json['unparsedResponse'] as String?,
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
