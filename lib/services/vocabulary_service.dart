import 'package:shared_preferences/shared_preferences.dart';

import '../models/vocabulary_entry.dart';
import '../models/vocabulary_level.dart';
import 'json_list_store.dart';

/// 単語帳のローカル保持。SharedPreferencesにJSON配列として保存するだけの
/// シンプルな構造（osmWashabeの `@AppStorage` 保存方針を踏襲）。
/// 保存順＝表示順。新規追加は先頭に挿入し、[reorderEntries]で並び替えられる。
class VocabularyService {
  static const hiddenBuiltinIdsKey = 'vocabulary.hiddenBuiltinIds';

  static final _store = JsonListStore<VocabularyEntry>(
    key: 'vocabulary.entries',
    fromJson: VocabularyEntry.fromJson,
    toJson: (entry) => entry.toJson(),
    idOf: (entry) => entry.id,
  );

  Future<List<VocabularyEntry>> loadEntries() => _store.loadAll();

  /// ユーザーが削除または編集した標準語彙のID。
  Future<Set<String>> loadHiddenBuiltinIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(hiddenBuiltinIdsKey) ?? const []).toSet();
  }

  /// 仮想エントリである標準語彙を非表示にする。
  Future<void> hideBuiltinEntry(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final hidden = await loadHiddenBuiltinIds();
    hidden.add(id);
    await prefs.setStringList(hiddenBuiltinIdsKey, hidden.toList()..sort());
  }

  /// 標準語彙を編集可能なユーザー語彙へ置き換える。
  Future<List<VocabularyEntry>> replaceBuiltinEntry(
    String builtinId, {
    required String word,
    required String reading,
    String exampleSentence = '',
    required String translation,
    required String translationLang,
    VocabularyLevel level = VocabularyLevel.other,
  }) async {
    final updated = await addEntry(
      word,
      translation,
      reading: reading,
      exampleSentence: exampleSentence,
      translationLang: translationLang,
      level: level,
    );
    await hideBuiltinEntry(builtinId);
    return updated;
  }

  Future<List<VocabularyEntry>> loadEntriesByLevel(
    VocabularyLevel level,
  ) async {
    final entries = await loadEntries();
    return entries.where((entry) => entry.level == level).toList();
  }

  Future<List<VocabularyEntry>> addEntry(
    String word,
    String translation, {
    String reading = '',
    String exampleSentence = '',
    String translationLang = 'vi',
    VocabularyLevel level = VocabularyLevel.other,
  }) async {
    final entries = await loadEntries();
    final entry = VocabularyEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      word: word.trim(),
      reading: reading.trim(),
      exampleSentence: exampleSentence.trim(),
      translation: translation.trim(),
      translationLang: translationLang,
      level: level,
      createdAt: DateTime.now(),
    );
    final updated = [entry, ...entries];
    await _store.saveAll(updated);
    return updated;
  }

  Future<List<VocabularyEntry>> updateEntry(
    String id, {
    required String word,
    required String reading,
    String exampleSentence = '',
    required String translation,
    required String translationLang,
    VocabularyLevel level = VocabularyLevel.other,
  }) async {
    final entries = await loadEntries();
    final updated = [
      for (final entry in entries)
        if (entry.id == id)
          entry.copyWith(
            word: word.trim(),
            reading: reading.trim(),
            exampleSentence: exampleSentence.trim(),
            translation: translation.trim(),
            translationLang: translationLang,
            level: level,
          )
        else
          entry,
    ];
    await _store.saveAll(updated);
    return updated;
  }

  Future<List<VocabularyEntry>> deleteEntry(String id) async {
    final entries = await loadEntries();
    final updated = entries.where((e) => e.id != id).toList();
    await _store.saveAll(updated);
    return updated;
  }

  /// [orderedIds]の順に並び替えて保存する。含まれないIDは末尾に残す。
  Future<List<VocabularyEntry>> reorderEntries(List<String> orderedIds) async {
    final entries = await loadEntries();
    final byId = {for (final e in entries) e.id: e};
    final reordered = <VocabularyEntry>[
      for (final id in orderedIds) ?byId.remove(id),
    ];
    reordered.addAll(byId.values);
    await _store.saveAll(reordered);
    return reordered;
  }
}
