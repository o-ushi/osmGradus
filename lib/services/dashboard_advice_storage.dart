import 'package:shared_preferences/shared_preferences.dart';

/// ダッシュボードの総合アドバイス文言をローカル保存する。
/// Chrome AIから貼り付けたテキストを保持し、次回起動時も表示する。
class DashboardAdviceStorage {
  static const _key = 'dashboard.advice';

  Future<String?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString(_key)?.trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  Future<void> save(String advice) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, advice.trim());
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
