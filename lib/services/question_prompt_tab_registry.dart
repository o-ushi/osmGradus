import 'package:shared_preferences/shared_preferences.dart';

/// 問題文（[TopicCategory.general]）のタブ分類レジストリ
/// （`docs/prompts/question-prompt-tabs.md` Step 1）。
///
/// 組み込み6タブ（[builtInTabKeys]、削除不可・表示順固定）に加えて、
/// ユーザーが追加できる独自タブをSharedPreferencesで管理する。タブ名
/// （storageKey）は表示の日本語ソースそのもの（`gradus_l10n`で翻訳、
/// ユーザーが作った独自タブは翻訳せず保存文字列のまま表示する想定）。
class QuestionPromptTabRegistry {
  static const _customTabsKey = 'questionPromptTabs.custom';

  /// タブ名の最大長。UIでの折り返し・チップ表示崩れを避けるための簡易上限。
  static const maxTabNameLength = 20;

  /// 組み込みタブ（storageKey＝日本語）。ユーザーは削除できない。
  /// 一覧・選択UIでの表示順はこの並びをそのまま使う。
  static const builtInTabKeys = <String>['趣味', '健康', '旅行', '家族', '環境', '会社'];

  /// 組み込み＋独自タブを表示順（組み込みが先）で返す。重複は除去する。
  Future<List<String>> allTabKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final custom = prefs.getStringList(_customTabsKey) ?? const [];
    final seen = builtInTabKeys.toSet();
    final result = [...builtInTabKeys];
    for (final tab in custom) {
      if (seen.add(tab)) result.add(tab);
    }
    return result;
  }

  /// 独自タブのみを保存順で返す。
  Future<List<String>> customTabKeys() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_customTabsKey) ?? const [];
  }

  /// 組み込みタブかどうか。
  bool isBuiltInTab(String name) => builtInTabKeys.contains(name);

  /// 独自タブかどうか（現時点のレジストリに存在するか）。
  Future<bool> isCustomTab(String name) async {
    final custom = await customTabKeys();
    return custom.contains(name);
  }

  /// 独自タブの名前を変更する。組み込みと同名・既存タブと同名・
  /// 空文字・長さ超過・存在しない旧名の場合は false。
  Future<bool> renameCustomTab(String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed.length > maxTabNameLength) return false;
    if (builtInTabKeys.contains(trimmed)) return false;

    final prefs = await SharedPreferences.getInstance();
    final custom = prefs.getStringList(_customTabsKey) ?? const [];
    if (!custom.contains(oldName)) return false;
    if (custom.contains(trimmed)) return false;

    await prefs.setStringList(
      _customTabsKey,
      [for (final tab in custom) tab == oldName ? trimmed : tab],
    );
    return true;
  }

  /// 独自タブを削除する。組み込みタブや存在しない名前は false。
  Future<bool> deleteCustomTab(String name) async {
    if (builtInTabKeys.contains(name)) return false;

    final prefs = await SharedPreferences.getInstance();
    final custom = prefs.getStringList(_customTabsKey) ?? const [];
    if (!custom.contains(name)) return false;

    await prefs.setStringList(
      _customTabsKey,
      custom.where((tab) => tab != name).toList(),
    );
    return true;
  }

  /// 独自タブを追加する。前後の空白はトリムし、空文字・[maxTabNameLength]
  /// 超過・既存タブ（組み込み・独自いずれか）と同名は無視する
  /// （呼び出し元へは例外を投げず、何もせず戻る）。
  Future<void> addCustomTab(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > maxTabNameLength) return;

    final prefs = await SharedPreferences.getInstance();
    final custom = prefs.getStringList(_customTabsKey) ?? const [];
    if (builtInTabKeys.contains(trimmed) || custom.contains(trimmed)) return;

    await prefs.setStringList(_customTabsKey, [...custom, trimmed]);
  }
}
