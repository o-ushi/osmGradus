import 'dart:io';
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// 無音ループでバックグラウンド動作を維持する。
/// Android で Chrome 往復時にプロセスが落ちるのを防ぐ（osmWashabe と同方式）。
class BackgroundAudioKeeper {
  BackgroundAudioKeeper._();
  static final BackgroundAudioKeeper instance = BackgroundAudioKeeper._();

  final AudioPlayer _player = AudioPlayer();
  bool _isRunning = false;
  bool _pausedForSpeech = false;
  String? _silencePath;

  bool get isRunning => _isRunning;

  bool get isPausedForSpeech => _pausedForSpeech;

  /// 実際にプレイヤーが再生中かどうか（Android で OS が再生を止めた場合を検知）。
  bool get isActuallyPlaying => _isRunning && _player.playing;

  Future<void> pauseForSpeech() async {
    if (!_isRunning || _pausedForSpeech) return;
    _pausedForSpeech = true;
    try {
      await _player.pause();
      if (Platform.isAndroid) return;
      final session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
        ),
      );
    } catch (_) {}
  }

  Future<void> resumeAfterSpeech() async {
    if (!_isRunning || !_pausedForSpeech) return;
    _pausedForSpeech = false;
    try {
      final session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.mixWithOthers,
        ),
      );
      await session.setActive(true);
    } catch (_) {}
    await recoverIfNeeded();
  }

  Future<void> start() async {
    if (_isRunning) {
      if (_pausedForSpeech) {
        _pausedForSpeech = false;
        await recoverIfNeeded();
      }
      return;
    }
    _isRunning = true;
    try {
      _silencePath ??= await _ensureSilenceFile();
      await _player.setLoopMode(LoopMode.one);
      await _player.setVolume(0);
      await _player.setAudioSource(AudioSource.file(_silencePath!));

      if (_pausedForSpeech) return;

      final session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.mixWithOthers,
        ),
      );
      await session.setActive(true);
      await _player.play();
    } catch (_) {
      _isRunning = false;
    }
  }

  Future<void> stop() async {
    _isRunning = false;
    _pausedForSpeech = false;
    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<void> recoverIfNeeded() async {
    if (!_isRunning) return;
    if (_player.playing) return;
    try {
      if (_silencePath != null) {
        await _player.setAudioSource(AudioSource.file(_silencePath!));
        await _player.play();
      }
    } catch (_) {}
  }

  Future<String> _ensureSilenceFile() async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/osm_gradus_silence.wav');
    if (!file.existsSync()) {
      await file.writeAsBytes(_buildMinimalWav());
    }
    return file.path;
  }

  Uint8List _buildMinimalWav() {
    const sampleRate = 44100;
    const frameCount = 4410;
    const dataSize = frameCount * 2;
    const fileSize = 36 + dataSize;
    final wav = BytesBuilder();
    void append32(int v) {
      final b = ByteData(4)..setUint32(0, v, Endian.little);
      wav.add(b.buffer.asUint8List());
    }

    void append16(int v) {
      final b = ByteData(2)..setUint16(0, v, Endian.little);
      wav.add(b.buffer.asUint8List());
    }

    wav.add('RIFF'.codeUnits);
    append32(fileSize);
    wav.add('WAVEfmt '.codeUnits);
    append32(16);
    append16(1);
    append16(1);
    append32(sampleRate);
    append32(sampleRate * 2);
    append16(2);
    append16(16);
    wav.add('data'.codeUnits);
    append32(dataSize);
    wav.add(Uint8List(dataSize));
    return wav.toBytes();
  }

  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }
}
