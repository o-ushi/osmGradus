import '../models/saved_scoring_result.dart';
import 'json_list_store.dart';

/// レイヤーⅣの採点結果を無制限にローカル保存するストレージ。
/// SQLite/Isar等は使わずSharedPreferencesにJSONで保存する
/// （`PodcastLibraryService`と同じ方式）。osmWashabeの「直近5件」上限は
/// 撤廃し、件数制限なしで保存する。
class ScoringResultStorage {
  static final _store = JsonListStore<SavedScoringResult>(
    key: 'layer4.scoringResults',
    fromJson: SavedScoringResult.fromJson,
    toJson: (result) => result.toJson(),
    idOf: (result) => result.id,
  );

  /// 新しい順。
  Future<List<SavedScoringResult>> loadAll() => _store.loadAll();

  /// 新しい結果を先頭に追加保存する（件数上限なし）。
  Future<void> save(SavedScoringResult result) => _store.save(result);

  Future<void> delete(String id) => _store.delete(id);

  /// 既存の採点結果を差し替える（レイヤーⅣのPREP・的中度AI評価を、採点直後
  /// ではなく後から同じレコードへ書き足すため）。並び順は変えない。
  Future<void> update(SavedScoringResult result) async {
    final all = await loadAll();
    final updated = [
      for (final item in all)
        if (item.id == result.id) result else item,
    ];
    await _store.saveAll(updated);
  }

  /// 保存済みの採点結果をすべて削除する（設定画面の「評価結果」リセット用）。
  Future<void> clearAll() => _store.clearAll();
}
