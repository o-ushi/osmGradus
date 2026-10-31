import 'long_article_comprehension_check.dart';
import 'long_article_vocab_word.dart';

/// 長文読解（レイヤーⅠ「長文読解」）で作成した長文1件。
/// 一覧保存・Layer Ⅴのランダム音読の前提データ。
class LongArticle {
  const LongArticle({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.isFavorite = false,
    this.sortOrder = 0,
    this.generationKeyword,
    this.generationJlptLevel,
    this.generationLength,
    this.comprehensionCheck,
    this.vocabTestWords = const [],
    this.vocabTestCorrectCount,
    this.vocabTestQuestionCount,
    this.lastVocabularyCheckId,
  });

  final String id;

  /// キーワードや本文冒頭の抜粋。一覧表示用。
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isFavorite;

  /// 表示順。小さいほど先に表示する。[LongArticleService]が並び替え時に
  /// 連番へ振り直す（保存順そのものと一致させる）。
  final int sortOrder;

  /// 生成に使ったキーワード（任意。手動作成や旧データではnull）。
  final String? generationKeyword;

  /// 生成に使ったJLPTレベルの保存キー（例: 'n1'。任意）。
  final String? generationJlptLevel;

  /// 生成時に指定した目安文字数（任意）。
  final int? generationLength;

  /// 生成AIレスポンスに同梱された1秒チェック（任意。旧データ・手動作成では
  /// null。nullならレイヤーⅠのクイズフェーズをスキップする）。
  final LongArticleComprehensionCheck? comprehensionCheck;

  /// 生成AIレスポンスに同梱された語彙テスト用単語（最大9語）のスナップショット。
  /// 旧データ・手動作成では空配列（＝語彙テストフェーズをスキップ）。
  final List<LongArticleVocabWord> vocabTestWords;

  /// 語彙テストの正解数。未実施はnull。
  final int? vocabTestCorrectCount;

  /// 語彙テストの出題数（[vocabTestWords.length]と対応する想定だが、実施後に
  /// [vocabTestWords]の内容が変わっても正解率の分母を保つため独立して持つ）。
  /// 未実施はnull。
  final int? vocabTestQuestionCount;

  /// 直近の語彙テスト結果（[SavedVocabularyCheck.id]）。結果詳細画面への
  /// 導線に使う。未実施・履歴未保存はnull。
  final String? lastVocabularyCheckId;

  /// 語彙テストの正解率（0.0〜1.0）。未実施はnull。
  double? get vocabTestAccuracy {
    final total = vocabTestQuestionCount;
    final correct = vocabTestCorrectCount;
    if (total == null || correct == null || total == 0) return null;
    return correct / total;
  }

  /// 語彙テスト実施済みか（出題数・正解数の両方が記録済みで、出題数が1件
  /// 以上のとき実施済みとする）。
  bool get hasVocabTestResult =>
      vocabTestQuestionCount != null && vocabTestQuestionCount! > 0;

  factory LongArticle.fromJson(Map<String, dynamic> json) => LongArticle(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    body: json['body'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(
      json['updatedAt'] as String? ?? json['createdAt'] as String,
    ),
    isFavorite: json['isFavorite'] as bool? ?? false,
    sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    generationKeyword: json['generationKeyword'] as String?,
    generationJlptLevel: json['generationJlptLevel'] as String?,
    generationLength: (json['generationLength'] as num?)?.toInt(),
    comprehensionCheck: json['comprehensionCheck'] is Map
        ? LongArticleComprehensionCheck.fromJson(
            Map<String, dynamic>.from(json['comprehensionCheck'] as Map),
          )
        : null,
    vocabTestWords: _vocabTestWordsFromJson(json['vocabTestWords']),
    vocabTestCorrectCount: (json['vocabTestCorrectCount'] as num?)?.toInt(),
    vocabTestQuestionCount: (json['vocabTestQuestionCount'] as num?)?.toInt(),
    lastVocabularyCheckId: json['lastVocabularyCheckId'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isFavorite': isFavorite,
    'sortOrder': sortOrder,
    'generationKeyword': generationKeyword,
    'generationJlptLevel': generationJlptLevel,
    'generationLength': generationLength,
    'comprehensionCheck': comprehensionCheck?.toJson(),
    if (vocabTestWords.isNotEmpty)
      'vocabTestWords': vocabTestWords.map((w) => w.toJson()).toList(),
    if (vocabTestCorrectCount != null)
      'vocabTestCorrectCount': vocabTestCorrectCount,
    if (vocabTestQuestionCount != null)
      'vocabTestQuestionCount': vocabTestQuestionCount,
    if (lastVocabularyCheckId != null)
      'lastVocabularyCheckId': lastVocabularyCheckId,
  };

  LongArticle copyWith({
    String? title,
    String? body,
    DateTime? updatedAt,
    bool? isFavorite,
    int? sortOrder,
    String? generationKeyword,
    String? generationJlptLevel,
    int? generationLength,
    LongArticleComprehensionCheck? comprehensionCheck,
    List<LongArticleVocabWord>? vocabTestWords,
    int? vocabTestCorrectCount,
    bool clearVocabTestCorrectCount = false,
    int? vocabTestQuestionCount,
    bool clearVocabTestQuestionCount = false,
    String? lastVocabularyCheckId,
    bool clearLastVocabularyCheckId = false,
  }) => LongArticle(
    id: id,
    title: title ?? this.title,
    body: body ?? this.body,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isFavorite: isFavorite ?? this.isFavorite,
    sortOrder: sortOrder ?? this.sortOrder,
    generationKeyword: generationKeyword ?? this.generationKeyword,
    generationJlptLevel: generationJlptLevel ?? this.generationJlptLevel,
    generationLength: generationLength ?? this.generationLength,
    comprehensionCheck: comprehensionCheck ?? this.comprehensionCheck,
    vocabTestWords: vocabTestWords ?? this.vocabTestWords,
    vocabTestCorrectCount: clearVocabTestCorrectCount
        ? null
        : (vocabTestCorrectCount ?? this.vocabTestCorrectCount),
    vocabTestQuestionCount: clearVocabTestQuestionCount
        ? null
        : (vocabTestQuestionCount ?? this.vocabTestQuestionCount),
    lastVocabularyCheckId: clearLastVocabularyCheckId
        ? null
        : (lastVocabularyCheckId ?? this.lastVocabularyCheckId),
  );

  static List<LongArticleVocabWord> _vocabTestWordsFromJson(Object? raw) {
    if (raw is! List) return const [];
    final result = <LongArticleVocabWord>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        result.add(
          LongArticleVocabWord.fromJson(Map<String, dynamic>.from(item)),
        );
      } catch (_) {
        continue;
      }
    }
    return result;
  }
}
