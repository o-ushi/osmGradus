/// レイヤーⅤ（発音チェック）の対象カテゴリ。
/// ベトナム語母語話者が苦手としやすい発音に絞る。
enum PronunciationCategory { tsu, zRow, rRow, longVowel, sokuon }

extension PronunciationCategoryLabel on PronunciationCategory {
  String get storageKey => switch (this) {
    PronunciationCategory.tsu => 'tsu',
    PronunciationCategory.zRow => 'zRow',
    PronunciationCategory.rRow => 'rRow',
    PronunciationCategory.longVowel => 'longVowel',
    PronunciationCategory.sokuon => 'sokuon',
  };

  String get label => switch (this) {
    PronunciationCategory.tsu => '「つ」',
    PronunciationCategory.zRow => '「ざ・ず・ぞ」',
    PronunciationCategory.rRow => 'ラ行',
    PronunciationCategory.longVowel => '長音',
    PronunciationCategory.sokuon => '促音',
  };

  static PronunciationCategory fromStorageKey(String key) =>
      PronunciationCategory.values.firstWhere(
        (category) => category.storageKey == key,
        orElse: () => throw ArgumentError('Unknown PronunciationCategory: $key'),
      );
}

/// 発音課題の出所。組み込み（builtIn）かユーザーが取り込んだもの（imported）か。
enum PronunciationExerciseSource { builtIn, imported }

extension PronunciationExerciseSourceLabel on PronunciationExerciseSource {
  String get storageKey => switch (this) {
    PronunciationExerciseSource.builtIn => 'builtIn',
    PronunciationExerciseSource.imported => 'imported',
  };

  static PronunciationExerciseSource fromStorageKey(String key) =>
      PronunciationExerciseSource.values.firstWhere(
        (source) => source.storageKey == key,
        orElse: () =>
            throw ArgumentError('Unknown PronunciationExerciseSource: $key'),
      );
}

/// レイヤーⅤで出題する発音課題1件分。
class PronunciationExercise {
  const PronunciationExercise({
    required this.id,
    required this.category,
    required this.sentence,
    required this.reading,
    required this.targetExpressions,
    required this.vietnameseHint,
    required this.evaluationPoint,
    required this.source,
  });

  /// 永続化後も変わらない安定したID。
  final String id;
  final PronunciationCategory category;

  /// 出題文（日本語）。
  final String sentence;

  /// 読み仮名。
  final String reading;

  /// 発音を評価する対象の表現（文中の一部）。
  final List<String> targetExpressions;

  /// ベトナム語での注意点の説明。
  final String vietnameseHint;

  /// 何を評価基準にするかの説明（日本語）。
  final String evaluationPoint;

  final PronunciationExerciseSource source;

  factory PronunciationExercise.fromJson(Map<String, dynamic> json) {
    return PronunciationExercise(
      id: json['id'] as String,
      category: PronunciationCategoryLabel.fromStorageKey(
        json['category'] as String,
      ),
      sentence: json['sentence'] as String,
      reading: json['reading'] as String,
      targetExpressions: (json['targetExpressions'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      vietnameseHint: json['vietnameseHint'] as String,
      evaluationPoint: json['evaluationPoint'] as String,
      source: PronunciationExerciseSourceLabel.fromStorageKey(
        json['source'] as String,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category.storageKey,
    'sentence': sentence,
    'reading': reading,
    'targetExpressions': targetExpressions,
    'vietnameseHint': vietnameseHint,
    'evaluationPoint': evaluationPoint,
    'source': source.storageKey,
  };
}
