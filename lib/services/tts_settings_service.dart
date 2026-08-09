import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 読み上げ（TTS）の声質・速度と、タイマー完了時のアラーム音の設定。
/// osmWashabeの`AppSettingsNotifier`/`AppPreferences`のうち、
/// 読み上げ・タイマー完了音に関わる部分のみを切り出した移植。
class TtsSettingsService extends ChangeNotifier {
  static const _voiceGenderKey = 'osm_gradus.tts.voiceGender';
  static const _speechRateKey = 'osm_gradus.tts.speechRate';
  static const _alarmSoundKey = 'osm_gradus.alarm.sound';
  static const _alarmSoundTitleKey = 'osm_gradus.alarm.soundTitle';

  static const defaultVoiceGender = '女性の声';
  static const defaultSpeechRate = 0.53;
  static const minSpeechRate = 0.35;
  static const maxSpeechRate = 0.68;

  /// アラーム音が未選択のときの表示名（既定は端末に依存しないシステム音を鳴らす）。
  static const defaultAlarmSoundTitle = '既定の通知音';

  SharedPreferences? _prefs;
  String _voiceGender = defaultVoiceGender;
  double _speechRate = defaultSpeechRate;
  String _alarmSound = '';
  String _alarmSoundTitle = defaultAlarmSoundTitle;

  String get speechVoiceGender => _voiceGender;
  double get speechRate => _speechRate;

  /// Android: URI, iOS: ファイルパス。空文字は「未選択（既定の通知音）」を表す。
  String get alarmSound => _alarmSound;
  String get alarmSoundTitle => _alarmSoundTitle;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    _voiceGender = prefs.getString(_voiceGenderKey) ?? defaultVoiceGender;
    _speechRate = (prefs.getDouble(_speechRateKey) ?? defaultSpeechRate).clamp(
      minSpeechRate,
      maxSpeechRate,
    );
    _alarmSound = prefs.getString(_alarmSoundKey) ?? '';
    _alarmSoundTitle =
        prefs.getString(_alarmSoundTitleKey) ?? defaultAlarmSoundTitle;
    notifyListeners();
  }

  Future<void> setSpeechVoiceGender(String value) async {
    _voiceGender = value;
    notifyListeners();
    await _prefs?.setString(_voiceGenderKey, value);
  }

  Future<void> setSpeechRate(double value) async {
    _speechRate = value.clamp(minSpeechRate, maxSpeechRate);
    notifyListeners();
    await _prefs?.setDouble(_speechRateKey, _speechRate);
  }

  Future<void> setAlarmSound(String storedValue, String title) async {
    _alarmSound = storedValue;
    _alarmSoundTitle = title;
    notifyListeners();
    await _prefs?.setString(_alarmSoundKey, storedValue);
    await _prefs?.setString(_alarmSoundTitleKey, title);
  }
}
