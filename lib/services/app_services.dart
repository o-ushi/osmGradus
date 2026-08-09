import '../audio/podcast_audio_handler.dart';
import '../notifiers/app_settings.dart';
import '../services/app_preferences.dart';
import '../services/jsst_calibration_preferences.dart';
import '../services/topic_speech_reader.dart';
import '../services/tts_settings_service.dart';

/// アプリ全体で共有するサービス群の登録先。
/// [main] で初期化し、各画面はここ経由で依存を参照する。
abstract final class AppServices {
  static late final PodcastAudioHandler audioHandler;
  static late final TtsSettingsService ttsSettings;
  static late final TopicSpeechReader topicSpeechReader;
  static late final JsstCalibrationPreferences jsstCalibrationPreferences;
  static late final AppPreferences appPreferences;
  static late final AppSettings appSettings;
}
