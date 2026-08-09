import 'vocabulary_entry.dart';

/// 単語テスト1問の回答状態（[PronunciationQuestionStatus]と同型）。
enum VocabTestQuestionStatus {
  waiting,
  recording,
  transcribing,
  completed,
  failed,
}

/// セッション内の1問分。出題する単語（[entry]）は不変だが、回答状態と
/// STT結果は録音の進行に伴って変化する。
class VocabTestQuestion {
  VocabTestQuestion({
    required this.entry,
    this.status = VocabTestQuestionStatus.waiting,
    this.sttResult,
    this.answerLanguageCode,
  });

  /// 出題する単語（この問の「期待単語」）。
  final VocabularyEntry entry;
  VocabTestQuestionStatus status;

  /// 音声認識結果のテキスト。未回答またはリセット後はnull。
  String? sttResult;

  /// 学習者が回答した言語（'vi' / 'en' / 'ja'）。
  /// 音声・キーボードとも画面の回答言語ボタン（🇻🇳/🇺🇸/🇯🇵）の選択を記録する。
  String? answerLanguageCode;
}

/// 1回の単語テストセッション（最大10問、同一試験内で単語の重複はない）。
/// 出題する単語の抽選自体は呼び出し側（[Layer1VocabScreenState]）が担い、
/// このクラスは抽選済みの単語列を受け取って現在位置と各問題の状態を保持する
/// （[PronunciationPracticeSession]と同じ役割分担）。
class VocabTestSession {
  VocabTestSession({required this.questions}) : currentIndex = 0;

  final List<VocabTestQuestion> questions;
  int currentIndex;

  int get questionCount => questions.length;

  VocabTestQuestion get current => questions[currentIndex];

  bool get hasNext => currentIndex < questions.length - 1;

  bool get hasPrevious => currentIndex > 0;

  bool get allAnswered => questions.every(
    (q) =>
        q.status == VocabTestQuestionStatus.completed ||
        q.status == VocabTestQuestionStatus.failed,
  );

  /// 次の問題へ進む。最後の問題では何もしない。
  void next() {
    if (hasNext) currentIndex++;
  }

  /// 前の問題へ戻る。先頭の問題では何もしない。
  void previous() {
    if (hasPrevious) currentIndex--;
  }

  /// キーボード入力で前の問題へ戻って修正するとき、回答済みの問題を
  /// 再編集可能な状態に戻す（[sttResult]はそのまま残す）。
  void reopenCurrentForEditing() {
    current.status = VocabTestQuestionStatus.waiting;
  }

  void setStatus(VocabTestQuestionStatus status) {
    current.status = status;
  }

  /// STT結果を記録し、状態をcompletedにする。
  void completeWithResult(
    String sttResult, {
    String? answerLanguageCode,
  }) {
    current.sttResult = sttResult;
    current.answerLanguageCode = answerLanguageCode;
    current.status = VocabTestQuestionStatus.completed;
  }

  /// STTが失敗した場合の状態遷移。
  void markFailed() {
    current.status = VocabTestQuestionStatus.failed;
  }
}
