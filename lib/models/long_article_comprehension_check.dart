/// 長文読解の生成結果に同梱される「1秒チェック」（文脈理解を問う2択クイズ）。
class LongArticleComprehensionCheck {
  const LongArticleComprehensionCheck({
    required this.question,
    required this.optionA,
    required this.optionB,
    required this.correctOption,
    required this.explanation,
  });

  final String question;
  final String optionA;
  final String optionB;

  /// `"A"` または `"B"`。
  final String correctOption;

  /// 正解／不正解の1行解説。
  final String explanation;

  static const _validCorrectOptions = {'A', 'B'};

  /// AI生成レスポンス由来の未検証データ用。必須キーが全て空でない文字列と
  /// して揃っており、[correctOption]が`"A"`/`"B"`のいずれかである場合のみ
  /// インスタンスを返す。それ以外（欠落・空文字・不正値）はnull。
  static LongArticleComprehensionCheck? fromJsonOrNull(Object? json) {
    if (json is! Map) return null;
    final question = json['question'];
    final optionA = json['optionA'];
    final optionB = json['optionB'];
    final correctOption = json['correctOption'];
    final explanation = json['explanation'];
    if (question is! String || question.trim().isEmpty) return null;
    if (optionA is! String || optionA.trim().isEmpty) return null;
    if (optionB is! String || optionB.trim().isEmpty) return null;
    if (explanation is! String || explanation.trim().isEmpty) return null;
    if (correctOption is! String ||
        !_validCorrectOptions.contains(correctOption)) {
      return null;
    }
    return LongArticleComprehensionCheck(
      question: question.trim(),
      optionA: optionA.trim(),
      optionB: optionB.trim(),
      correctOption: correctOption,
      explanation: explanation.trim(),
    );
  }

  /// 永続化済み（保存時に既に検証済みの）データ用。
  factory LongArticleComprehensionCheck.fromJson(Map<String, dynamic> json) =>
      LongArticleComprehensionCheck(
        question: json['question'] as String? ?? '',
        optionA: json['optionA'] as String? ?? '',
        optionB: json['optionB'] as String? ?? '',
        correctOption: json['correctOption'] as String? ?? 'A',
        explanation: json['explanation'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
    'question': question,
    'optionA': optionA,
    'optionB': optionB,
    'correctOption': correctOption,
    'explanation': explanation,
  };

  LongArticleComprehensionCheck copyWith({
    String? question,
    String? optionA,
    String? optionB,
    String? correctOption,
    String? explanation,
  }) => LongArticleComprehensionCheck(
    question: question ?? this.question,
    optionA: optionA ?? this.optionA,
    optionB: optionB ?? this.optionB,
    correctOption: correctOption ?? this.correctOption,
    explanation: explanation ?? this.explanation,
  );
}
