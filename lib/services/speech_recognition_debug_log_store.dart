import 'package:shared_preferences/shared_preferences.dart';

/// 音声認識（録音・文字起こし）の動きを端末に永続化するログストア。
/// osmWashabeの`SpeechRecognitionDebugLogStore`の移植。[AppLogger]と異なり
/// メモリ上のリングバッファではなく、追記のたびにSharedPreferencesへ
/// 書き込む（アプリがフリーズ/クラッシュして再起動したあとも、直前の
/// 動きを設定画面の「音声認識ログ」から確認できるようにするため）。
class SpeechRecognitionDebugLogStore {
  SpeechRecognitionDebugLogStore._();
  static final SpeechRecognitionDebugLogStore instance =
      SpeechRecognitionDebugLogStore._();

  static const _key = 'dev.speechRecognitionDebugLog';
  static const _maxEntries = 200;

  Future<void> add(String message) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_key) ?? const [];
    final line = '${DateTime.now().toIso8601String()}  $message';
    final updated = [...existing, line];
    final trimmed = updated.length > _maxEntries
        ? updated.sublist(updated.length - _maxEntries)
        : updated;
    await prefs.setStringList(_key, trimmed);
  }

  Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? const [];
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
