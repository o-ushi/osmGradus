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
  );
}
