/// 単語帳（[VocabularyEntry]）・語彙バンク（[JlptVocabularyBank]）で共有する
/// 出題レベル。ユーザーが手動登録した語や、レベル分類が無い旧データは
/// [other]として扱う。
enum VocabularyLevel { n1, n2, n3, other }

extension VocabularyLevelStorage on VocabularyLevel {
  String get storageKey => switch (this) {
    VocabularyLevel.n1 => 'n1',
    VocabularyLevel.n2 => 'n2',
    VocabularyLevel.n3 => 'n3',
    VocabularyLevel.other => 'other',
  };

  /// 未知の値・null（旧データにlevelフィールドが無い場合）は[VocabularyLevel.other]
  /// として読み込む。
  static VocabularyLevel fromStorageKey(String? key) => switch (key) {
    'n1' => VocabularyLevel.n1,
    'n2' => VocabularyLevel.n2,
    'n3' => VocabularyLevel.n3,
    _ => VocabularyLevel.other,
  };
}
