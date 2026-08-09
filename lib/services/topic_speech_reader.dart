import 'dart:io';
import 'dart:math';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

import 'background_audio_keeper.dart';
import 'japanese_speech_text_formatter.dart';
import 'japanese_speech_voice_selector.dart';
import 'native_tts_platform.dart';
import 'speech_voice_platform.dart';
import 'tts_settings_service.dart';

/// osmWashabeの`TopicSpeechReader`の移植。iOS/Androidそれぞれのネイティブ
/// TTS（`NativeTtsPlatform`）を使い、音声選択を確実にする
/// （flutter_ttsプラグインには依存しない）。`BackgroundAudioKeeper`
/// （無音キープアライブ、Chrome往復時のプロセス落ち対策）との連携も
/// osmWashabeと同じ手順で行う。
class TopicSpeechReader extends ChangeNotifier {
  TopicSpeechReader(this._settings) {
    _settings.addListener(_onSettingsChanged);
    _applyVoiceSettings();
  }

  final TtsSettingsService _settings;

  bool _isSpeaking = false;
  bool _isPaused = false;
  bool _utteranceActive = false;
  int _speakEpoch = 0;
  String? _lockedGender;
  bool _ttsAvailable = true;
  SpeechVoiceInfo _activeVoiceInfo = const SpeechVoiceInfo(
    name: 'Kyoko',
    qualityLabel: '標準',
    isHighQuality: false,
  );

  bool get isSpeaking => _isSpeaking;
  bool get isPaused => _isPaused;

  /// speak()のawait中（TTS開始前の準備を含む）。
  bool get isUtteranceActive => _utteranceActive || _isSpeaking;
  bool get isUsingHighQualityVoice => _activeVoiceInfo.isHighQuality;

  /// falseのとき日本語TTSが端末にインストールされていない。
  bool get ttsAvailable => _ttsAvailable;

  String get activeVoiceDescription =>
      '${_activeVoiceInfo.name}（${_activeVoiceInfo.qualityLabel}）';

  void _onSettingsChanged() {
    _applyVoiceSettings();
  }

  Future<void> _applyVoiceSettings() async {
    if (NativeTtsPlatform.isSupported) {
      final info = await SpeechVoicePlatform.getVoiceInfoForGender(
        _settings.speechVoiceGender,
      );
      if (info != null) {
        final qualityLabel = _qualityLabel(
          info['quality'] ?? '',
          info['identifier'] ?? '',
        );
        final isHQ =
            info['quality'] == 'premium' || info['quality'] == 'enhanced';
        _activeVoiceInfo = SpeechVoiceInfo(
          name: info['name'] ?? 'Kyoko',
          qualityLabel: qualityLabel,
          isHighQuality: isHQ,
        );
      }
    }
    notifyListeners();
  }

  static String _qualityLabel(String quality, String identifier) {
    if (quality == 'premium' || identifier.toLowerCase().contains('premium')) {
      return 'プレミアム';
    }
    if (quality == 'enhanced' ||
        identifier.toLowerCase().contains('enhanced')) {
      return '高品質';
    }
    return '標準';
  }

  Future<bool> speak({
    required String text,
    double pitchMultiplier = 1.0,
    double rateBoost = 0.0,
    VoidCallback? onFinish,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      onFinish?.call();
      return true;
    }

    final epoch = ++_speakEpoch;
    _utteranceActive = true;
    notifyListeners();

    try {
      if (_isSpeaking) {
        _isPaused = false;
        _isSpeaking = false;
        if (NativeTtsPlatform.isSupported) {
          await NativeTtsPlatform.stop();
        }
      }

      if (epoch != _speakEpoch) return false;

      // 無音キープアライブが動いていれば、TTSと競合しないよう一時停止/停止する。
      final keeperWasRunning = BackgroundAudioKeeper.instance.isRunning;
      if (keeperWasRunning) {
        if (Platform.isAndroid) {
          await BackgroundAudioKeeper.instance.stop();
        } else {
          await BackgroundAudioKeeper.instance.pauseForSpeech();
        }
      }

      try {
        await ensureSpeechAudioSession();
        if (epoch != _speakEpoch) return false;

        if (NativeTtsPlatform.isSupported) {
          return await _speakNative(
            text: trimmed,
            epoch: epoch,
            pitchMultiplier: pitchMultiplier,
            rateBoost: rateBoost,
            onFinish: onFinish,
          );
        }
        return false;
      } finally {
        if (epoch == _speakEpoch && keeperWasRunning && !Platform.isAndroid) {
          await BackgroundAudioKeeper.instance.resumeAfterSpeech();
        }
      }
    } finally {
      if (epoch == _speakEpoch) {
        _utteranceActive = false;
        notifyListeners();
      }
    }
  }

  /// ネイティブTTS: 性別をOS側に渡し、日本語音声を直接選択して発話する。
  Future<bool> _speakNative({
    required String text,
    required int epoch,
    required double pitchMultiplier,
    required double rateBoost,
    VoidCallback? onFinish,
  }) async {
    final rate = (_settings.speechRate + rateBoost).clamp(
      TtsSettingsService.minSpeechRate,
      TtsSettingsService.maxSpeechRate,
    );
    final rawGender = _settings.speechVoiceGender;
    // ランダムの場合は質問ごとに男女を1度だけ決定し、同じ質問内の全発話に同じ声を使う。
    final String gender;
    if (SpeechVoiceGender.fromStored(rawGender) == SpeechVoiceGender.random) {
      _lockedGender ??= Random().nextBool()
          ? SpeechVoiceGender.male.rawValue
          : SpeechVoiceGender.female.rawValue;
      gender = _lockedGender!;
    } else {
      gender = rawGender;
    }

    _isSpeaking = true;
    notifyListeners();

    final chunks = JapaneseSpeechTextFormatter.utteranceChunks(text);
    // true=正常完了, false=キャンセル/エンジンエラー, null相当=日本語TTS未インストール（スキップ扱い）
    var allSucceeded = true;
    var ttsSkipped = false;
    for (final chunk in chunks) {
      if (epoch != _speakEpoch || !_isSpeaking) break;
      final ok = await NativeTtsPlatform.speak(
        text: chunk,
        gender: gender,
        rate: rate,
        pitch: pitchMultiplier,
      );
      if (epoch != _speakEpoch || !_isSpeaking) break;
      if (ok == null) {
        ttsSkipped = true;
        if (_ttsAvailable) _ttsAvailable = false;
        break;
      }
      if (!ok) {
        allSucceeded = false;
        break;
      }
    }

    if (epoch != _speakEpoch) return false;

    if (_isSpeaking) {
      _isSpeaking = false;
      notifyListeners();
      final succeeded = allSucceeded || ttsSkipped;
      if (succeeded) onFinish?.call();
      return succeeded;
    }

    await _deactivateSessionIfPossible();
    return false;
  }

  void clearGenderLock() => _lockedGender = null;

  Future<void> stop() async {
    _speakEpoch++;
    final wasSpeakingOrPaused = _isSpeaking || _isPaused || _utteranceActive;
    _utteranceActive = false;
    _isSpeaking = false;
    _isPaused = false;
    if (!wasSpeakingOrPaused) return;
    if (NativeTtsPlatform.isSupported) {
      await NativeTtsPlatform.stop();
    }
    notifyListeners();
    await _deactivateSessionIfPossible();
  }

  void pause() {
    if (!_isSpeaking || _isPaused) return;
    _isPaused = true;
    if (NativeTtsPlatform.isSupported) NativeTtsPlatform.pause();
    notifyListeners();
  }

  void resume() {
    if (!_isPaused) return;
    _isPaused = false;
    if (NativeTtsPlatform.isSupported) NativeTtsPlatform.resume();
    notifyListeners();
  }

  Future<void> _deactivateSessionIfPossible() async {
    if (BackgroundAudioKeeper.instance.isRunning) return;
    try {
      final session = await AudioSession.instance;
      if (BackgroundAudioKeeper.instance.isRunning) return;
      await session.setActive(false);
    } catch (_) {}
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }
}

/// 読み上げ前にオーディオセッションをplaybackに戻す。
/// STT後にplayAndRecordのまま残るとiOSでTTSが無音になる。キープアライブ
/// 稼働中はmixWithOthersを維持するが、TTS一時停止中は外す。
Future<void> ensureSpeechAudioSession() async {
  try {
    final session = await AudioSession.instance;
    final keeper = BackgroundAudioKeeper.instance;
    final keeperRunning = !Platform.isAndroid && keeper.isRunning;
    final useMixWithOthers = keeperRunning && !keeper.isPausedForSpeech;
    if (useMixWithOthers) {
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.mixWithOthers,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.media,
          ),
        ),
      );
    } else {
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.media,
          ),
        ),
      );
    }
    await session.setActive(true);
  } catch (_) {}
}
