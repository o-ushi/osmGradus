import 'dart:async';

import 'package:just_audio/just_audio.dart';

/// 準備カウントダウンの秒読みビープ・フェーズ切り替え音を鳴らす。
/// `SystemSound.play()`は端末の「サウンドエフェクト」設定やマナーモードの
/// 影響で鳴らないことがある（実機で確認済み）ため、TTSと同じ実音声再生
/// （just_audio）で確実に鳴らす。毎回`setAsset`し直すと1秒周期の再生が
/// ぎこちなくなるため、初回だけ読み込み、以降は`seek(0)+play`だけで鳴らす
/// （osmWashabeの`TickBeepPlayer`と同じ最適化）。
class TickBeepPlayer {
  TickBeepPlayer._();
  static final TickBeepPlayer instance = TickBeepPlayer._();

  final AudioPlayer _player = AudioPlayer();
  bool _isReady = false;

  /// カウントダウン開始前に呼んでおくと、1回目のビープが読み込み待ちで
  /// 遅れなくなる。
  Future<void> warmUp() async {
    if (_isReady) return;
    try {
      await _player.setAsset('assets/sounds/tick_beep.wav');
      _isReady = true;
    } catch (_) {}
  }

  Future<void> play() async {
    try {
      if (!_isReady) await warmUp();
      await _player.seek(Duration.zero);
      unawaited(_player.play());
    } catch (_) {}
  }

  Future<void> dispose() => _player.dispose();
}
