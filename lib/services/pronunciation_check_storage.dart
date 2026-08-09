import '../models/saved_pronunciation_check.dart';
import 'json_list_store.dart';

/// レイヤーⅤの発音チェック結果を無制限にローカル保存するストレージ。
/// `ScoringResultStorage`（レイヤーⅣ）と同じ方式（SharedPreferencesにJSON配列）。
class PronunciationCheckStorage {
  static final _store = JsonListStore<SavedPronunciationCheck>(
    key: 'layer5.pronunciationChecks',
    fromJson: SavedPronunciationCheck.fromJson,
    toJson: (check) => check.toJson(),
    idOf: (check) => check.id,
    skipInvalidEntries: true,
  );

  /// 新しい順。1件のJSONが壊れていても読み飛ばし、他の結果は読み込む。
  Future<List<SavedPronunciationCheck>> loadAll() => _store.loadAll();

  Future<void> save(SavedPronunciationCheck check) => _store.save(check);

  Future<void> delete(String id) => _store.delete(id);

  /// 保存済みの発音チェック結果をすべて削除する（設定画面の「評価結果」リセット用）。
  Future<void> clearAll() => _store.clearAll();
}
