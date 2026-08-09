import '../models/saved_vocabulary_check.dart';
import 'json_list_store.dart';

/// レイヤーⅠ単語テストの結果保存（[PronunciationCheckStorage]と同じ役割）。
class VocabularyCheckStorage {
  static final _store = JsonListStore<SavedVocabularyCheck>(
    key: 'layer1Vocab.checks',
    fromJson: SavedVocabularyCheck.fromJson,
    toJson: (check) => check.toJson(),
    idOf: (check) => check.id,
    skipInvalidEntries: true,
  );

  Future<List<SavedVocabularyCheck>> loadAll() => _store.loadAll();
  Future<void> save(SavedVocabularyCheck check) => _store.save(check);
  Future<void> delete(String id) => _store.delete(id);
  Future<void> clearAll() => _store.clearAll();
}
