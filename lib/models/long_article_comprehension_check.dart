/// 長文読解の生成結果に同梱される「1秒チェック」（文脈理解を問う2択クイズ）。
///
/// 本文・問題文・選択肢は読解対象の日本語のまま（レイヤーⅠの練習素材）だが、
/// 解説は学習者の表示言語（ja/en/vi）で読めるよう3言語分を保持する。
class LongArticleComprehensionCheck {
  const LongArticleComprehensionCheck({
    required this.question,
    required this.optionA,
    required this.optionB,
    required this.correctOption,
    required this.explanationJa,
    required this.explanationEn,
    required this.explanationVi,
  });

  final String question;
  final String optionA;
  final String optionB;

  /// `"A"` または `"B"`。
  final String correctOption;

  /// 正解／不正解の1行解説（日本語）。
  final String explanationJa;

  /// 同上（英語）。
  final String explanationEn;

  /// 同上（ベトナム語）。
  final String explanationVi;

  /// [languageCode]（'ja'/'en'/'vi'）に対応する解説。未知の言語コードは
  /// 日本語にフォールバックする。
  String explanationFor(String languageCode) => switch (languageCode) {
    'en' => explanationEn,
    'vi' => explanationVi,
    _ => explanationJa,
  };

  static const _validCorrectOptions = {'A', 'B'};

  /// `explanation`の値（新形式: `{"ja": ..., "en": ..., "vi": ...}`、
  /// または旧形式: 単一文字列）を(ja, en, vi)へ正規化する。
  /// 旧形式（単一文字列）は3言語とも同じ文言として扱う（後方互換）。
  /// どちらの形にも当てはまらない・空文字を含む場合はnull。
  static (String, String, String)? _normalizeExplanation(Object? value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : (trimmed, trimmed, trimmed);
    }
    if (value is Map) {
      final ja = value['ja'];
      final en = value['en'];
      final vi = value['vi'];
      if (ja is String &&
          en is String &&
          vi is String &&
          ja.trim().isNotEmpty &&
          en.trim().isNotEmpty &&
          vi.trim().isNotEmpty) {
        return (ja.trim(), en.trim(), vi.trim());
      }
    }
    return null;
  }

  /// AI生成レスポンス由来の未検証データ用。必須キーが全て空でない文字列と
  /// して揃っており、[correctOption]が`"A"`/`"B"`のいずれかである場合のみ
  /// インスタンスを返す。それ以外（欠落・空文字・不正値）はnull。
  static LongArticleComprehensionCheck? fromJsonOrNull(Object? json) {
    if (json is! Map) return null;
    final question = json['question'];
    final optionA = json['optionA'];
    final optionB = json['optionB'];
    final correctOption = json['correctOption'];
    final explanation = _normalizeExplanation(json['explanation']);
    if (question is! String || question.trim().isEmpty) return null;
    if (optionA is! String || optionA.trim().isEmpty) return null;
    if (optionB is! String || optionB.trim().isEmpty) return null;
    if (explanation == null) return null;
    if (correctOption is! String ||
        !_validCorrectOptions.contains(correctOption)) {
      return null;
    }
    return LongArticleComprehensionCheck(
      question: question.trim(),
      optionA: optionA.trim(),
      optionB: optionB.trim(),
      correctOption: correctOption,
      explanationJa: explanation.$1,
      explanationEn: explanation.$2,
      explanationVi: explanation.$3,
    );
  }

  /// 永続化済み（保存時に既に検証済みの）データ用。
  factory LongArticleComprehensionCheck.fromJson(Map<String, dynamic> json) {
    final explanation =
        _normalizeExplanation(json['explanation']) ?? ('', '', '');
    return LongArticleComprehensionCheck(
      question: json['question'] as String? ?? '',
      optionA: json['optionA'] as String? ?? '',
      optionB: json['optionB'] as String? ?? '',
      correctOption: json['correctOption'] as String? ?? 'A',
      explanationJa: explanation.$1,
      explanationEn: explanation.$2,
      explanationVi: explanation.$3,
    );
  }

  Map<String, dynamic> toJson() => {
    'question': question,
    'optionA': optionA,
    'optionB': optionB,
    'correctOption': correctOption,
    'explanation': {
      'ja': explanationJa,
      'en': explanationEn,
      'vi': explanationVi,
    },
  };

  LongArticleComprehensionCheck copyWith({
    String? question,
    String? optionA,
    String? optionB,
    String? correctOption,
    String? explanationJa,
    String? explanationEn,
    String? explanationVi,
  }) => LongArticleComprehensionCheck(
    question: question ?? this.question,
    optionA: optionA ?? this.optionA,
    optionB: optionB ?? this.optionB,
    correctOption: correctOption ?? this.correctOption,
    explanationJa: explanationJa ?? this.explanationJa,
    explanationEn: explanationEn ?? this.explanationEn,
    explanationVi: explanationVi ?? this.explanationVi,
  );
}
