import 'package:shared_preferences/shared_preferences.dart';

import 'recording_stt_service.dart';

/// 設定画面の「初期化」。osmGenkiの`AppReset`の移植。単語帳、レイヤーⅣ・Ⅴの
/// 保存結果を含む、ローカルに保存されたすべてのデータ・設定
/// （読み上げ設定・タイマー音・開発者モード・Podcast登録なども含む）を削除し、
/// 初めてインストールした状態に戻す。
abstract final class AppReset {
  static Future<void> resetToFactoryDefaults() async {
    await RecordingSttService.clearStoredRecordings();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
