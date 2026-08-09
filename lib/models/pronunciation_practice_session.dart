import 'pronunciation_exercise.dart';

/// 発音課題1問の回答状態。
enum PronunciationQuestionStatus {
  waiting,
  recording,
  transcribing,
  completed,
  failed,
}

/// セッション内の1問分。課題本体は不変だが、回答状態とSTT結果は
/// 録音の進行に伴って変化する。
class PronunciationPracticeQuestion {
  PronunciationPracticeQuestion({
    required this.exercise,
    this.status = PronunciationQuestionStatus.waiting,
    this.sttResult,
  });

  final PronunciationExercise exercise;
  PronunciationQuestionStatus status;

  /// 音声認識結果のテキスト。未回答またはリセット後はnull。
  String? sttResult;

  /// 状態をwaitingに戻し、STT結果を破棄する（再録音）。
  void reset() {
    status = PronunciationQuestionStatus.waiting;
    sttResult = null;
  }
}

/// 1回の発音練習セッション（5カテゴリ×2問=計10問、順序はシャッフル済み）。
/// 問題の抽選自体は[PronunciationExerciseService]が担い、このクラスは
/// 抽選済みの問題列を受け取って現在位置と各問題の状態を保持する。
class PronunciationPracticeSession {
  PronunciationPracticeSession({required this.questions}) : currentIndex = 0;

  final List<PronunciationPracticeQuestion> questions;
  int currentIndex;

  int get questionCount => questions.length;

  PronunciationPracticeQuestion get current => questions[currentIndex];

  bool get hasNext => currentIndex < questions.length - 1;
  bool get hasPrevious => currentIndex > 0;

  /// 次の問題へ進む。最後の問題では何もしない。
  void next() {
    if (hasNext) currentIndex++;
  }

  /// 前の問題へ戻る。最初の問題では何もしない。
  void previous() {
    if (hasPrevious) currentIndex--;
  }

  void setStatus(PronunciationQuestionStatus status) {
    current.status = status;
  }

  /// STT結果を記録し、状態をcompletedにする。
  void completeWithResult(String sttResult) {
    current.sttResult = sttResult;
    current.status = PronunciationQuestionStatus.completed;
  }

  /// STTが失敗した場合の状態遷移。
  void markFailed() {
    current.status = PronunciationQuestionStatus.failed;
  }

  /// 現在の問題を再録音するために状態をwaitingへ戻す。
  void retryCurrent() {
    current.reset();
  }
}
