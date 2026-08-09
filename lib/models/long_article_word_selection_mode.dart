/// 長文読解の長押し＋ドラッグでの単語選択（[TappableJapaneseText]）が使う
/// ヒットテスト単位。タップ即時登録・既登録語ハイライトは常にチャンク単位
/// （漢字・カタカナの連続をまとめた単位）で、この設定はドラッグ操作の
/// 粒度だけを切り替える（osmCogitoの`CogitoWordSelectionMode`を移植）。
enum LongArticleWordSelectionMode {
  /// 1文字ずつ（漢字・カタカナも連続マージしない）。既定。
  /// Galaxy S24等、タッチ座標のノイズが大きい端末での誤選択を抑える。
  character,

  /// 漢字・カタカナの連続をまとめた単語単位（旧方式）。長押しした瞬間に
  /// 単語・熟語ごとまとめて選ばれる。
  chunk,
}

extension LongArticleWordSelectionModeStorage on LongArticleWordSelectionMode {
  String get storageKey => name;
}

/// 永続化されたキー文字列から復元する。不正な値・未設定なら既定の
/// [LongArticleWordSelectionMode.character]。
LongArticleWordSelectionMode longArticleWordSelectionModeFromStorageKey(
  String? key,
) => switch (key) {
  'chunk' => LongArticleWordSelectionMode.chunk,
  _ => LongArticleWordSelectionMode.character,
};
