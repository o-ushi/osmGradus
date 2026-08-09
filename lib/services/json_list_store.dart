import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferencesの文字列配列に、モデルをJSON化して保存する共通ロジック。
/// `ScoringResultStorage`・`PronunciationCheckStorage`・`VocabularyService`が
/// それぞれ個別に持っていた「JSON配列のload/save/delete/clearAll」を1箇所に
/// まとめたもの。新しい順（先頭が最新）で保存する。
class JsonListStore<T> {
  const JsonListStore({
    required this.key,
    required this.fromJson,
    required this.toJson,
    this.idOf,
    this.skipInvalidEntries = false,
  });

  final String key;
  final T Function(Map<String, dynamic> json) fromJson;
  final Map<String, dynamic> Function(T item) toJson;

  /// [delete]で使う。渡さない場合、[delete]は呼べない。
  final String Function(T item)? idOf;

  /// trueの場合、1件のJSONが壊れていても読み飛ばし、他の要素は読み込む
  /// （`PronunciationCheckStorage`が使っていた挙動）。falseの場合は
  /// 壊れた要素があると例外を投げる（`ScoringResultStorage`が使っていた挙動）。
  final bool skipInvalidEntries;

  Future<List<T>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(key) ?? const [];
    if (!skipInvalidEntries) {
      return raw
          .map((s) => fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList();
    }
    final items = <T>[];
    for (final s in raw) {
      try {
        items.add(fromJson(jsonDecode(s) as Map<String, dynamic>));
      } catch (_) {
        continue;
      }
    }
    return items;
  }

  /// 新しい要素を先頭に追加保存する（件数上限なし）。
  Future<void> save(T item) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(key) ?? const [];
    final updated = [jsonEncode(toJson(item)), ...existing];
    await prefs.setStringList(key, updated);
  }

  /// [idOf]で識別されるIDが一致する要素を削除する。
  Future<void> delete(String id) async {
    assert(idOf != null, 'JsonListStore.delete()にはidOfが必要です');
    final items = await loadAll();
    await saveAll(items.where((item) => idOf!(item) != id).toList());
  }

  /// 現在の内容を丸ごと置き換える（並び替え・一括更新用）。
  Future<void> saveAll(List<T> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      key,
      items.map((item) => jsonEncode(toJson(item))).toList(),
    );
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
