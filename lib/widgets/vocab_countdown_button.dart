import 'dart:async';

import 'package:flutter/material.dart';

import 'topic_speaker_timer_button.dart';

/// レイヤーⅠ語彙テストの音声回答モード専用の10秒カウントダウン表示
/// （osmCogitoの`CogitoVocabCountdownButton`の移植）。
///
/// 見た目は[TopicSpeakerTimerButton]の`counting`状態（大きな白文字の残秒数）
/// をそのまま流用し、既存画面（発話タイマー等）とフォント・色・サイズを
/// 揃える。表示専用の[TopicSpeakerTimerButton]と違い、こちらはタイマー本体
/// （開始・停止・0秒到達の検知）を自前で持つ。
///
/// - タップ → 残秒に関係なく即座に[onTapEarlyFinish]を呼び、カウントダウンを止める。
/// - 0秒到達 → [onCountdownZero]を呼び、カウントダウンを止める。
///
/// 録音の開始/停止ロジックそのものには関与しない。呼び出し側
/// （[Layer1VocabScreen]）がこの2つのコールバックから、既存の
/// 「マイクタップで録音停止」と同じ処理へつなぐ。
class VocabCountdownButton extends StatefulWidget {
  const VocabCountdownButton({
    super.key,
    required this.onTapEarlyFinish,
    required this.onCountdownZero,
    this.seconds = 10,
    this.size = 98,
    this.autoStart = true,
  });

  /// カウントダウン開始秒数。
  final int seconds;

  /// タップして残秒に関係なく終了したときに呼ぶ。
  final VoidCallback onTapEarlyFinish;

  /// 0秒に到達したときに呼ぶ。
  final VoidCallback onCountdownZero;

  /// ボタンの高さ（[TopicSpeakerTimerButton.size]と同じ意味）。
  final double size;

  /// mount時に自動でカウントダウンを開始するか。falseの場合、呼び出し側が
  /// [VocabCountdownButtonState.start]を呼ぶまで待機する。
  final bool autoStart;

  @override
  State<VocabCountdownButton> createState() => VocabCountdownButtonState();
}

class VocabCountdownButtonState extends State<VocabCountdownButton> {
  Timer? _timer;
  late int _remainingSeconds = widget.seconds;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) start();
  }

  /// カウントダウンを（先頭から）開始する。既に動作中なら何もしない
  /// （多重起動防止）。
  void start() {
    if (_timer != null) return;
    setState(() => _remainingSeconds = widget.seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = _remainingSeconds - 1;
      if (!mounted) return;
      setState(() => _remainingSeconds = next);
      if (next <= 0) {
        stop();
        widget.onCountdownZero();
      }
    });
  }

  /// カウントダウンを止める（コールバックは呼ばない）。
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _handleTap() {
    if (_timer == null) return;
    stop();
    widget.onTapEarlyFinish();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TopicSpeakerTimerButton(
    phase: TopicSpeakerTimerPhase.counting,
    remainingSeconds: _remainingSeconds,
    onTap: _handleTap,
    size: widget.size,
  );

  /// 残秒数（テスト用）。
  @visibleForTesting
  int get debugRemainingSeconds => _remainingSeconds;

  /// カウントダウンが動作中か（テスト用）。
  @visibleForTesting
  bool get debugIsRunning => _timer != null;
}
