import 'pronunciation_exercise.dart'
    show PronunciationCategory, PronunciationCategoryLabel;

/// レイヤーⅤ「問題作成」（Step 6）でChrome AIが問題文に関連して作成する
/// 発音練習用の短文1件のスナップショット。[QuestionPrompt]側に複製で持たせ、
/// 「ランダム」（[Layer5Screen]）と同型のセッションUIへそのまま出題プールとして
/// 渡す（[PronunciationExercise]への変換は[Layer5ScreenState]側で行う）。
class QuestionPromptPronunciationSentence {
  const QuestionPromptPronunciationSentence({
    required this.text,
    required this.category,
    this.reading = '',
  });

  /// 出題文（日本語）。
  final String text;

  /// かな読み（任意）。
  final String reading;

  /// 採点対象の発音カテゴリ（つ／ざ行／ラ行／長音／促音）。
  final PronunciationCategory category;

  factory QuestionPromptPronunciationSentence.fromJson(
    Map<String, dynamic> json,
  ) => QuestionPromptPronunciationSentence(
    text: json['text'] as String,
    reading: json['reading'] as String? ?? '',
    category: PronunciationCategoryLabel.fromStorageKey(
      json['category'] as String,
    ),
  );

  Map<String, dynamic> toJson() => {
    'text': text,
    if (reading.isNotEmpty) 'reading': reading,
    'category': category.storageKey,
  };
}
