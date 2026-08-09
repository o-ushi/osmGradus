import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// レイヤーⅤ専用の大きな操作ボタン。[TopicSpeakerTimerButton]と同じ矩形・
/// サイズ規約（高さ[size]・幅[size]×2・角丸16）に合わせ、レイヤーⅡ〜Ⅳと
/// レイアウトの見た目を揃えるが、状態遷移ではなくタップだけで動作する。
///
/// レイヤーⅡ〜Ⅳのサイコロ→スピーカーと同じ2アイコン制：
///
/// - [armed]がfalse（サイコロ表示）：タップすると[onTap]を呼ぶ
///   （問題を表示／次の問題へ進める）。
/// - [armed]がtrue（マイク表示、背景は[recording]に応じて透明/赤）：
///   タップすると[onTap]を呼ぶ（1回目のタップで録音開始＝背景が赤に、
///   赤の状態でもう1回タップすると録音終了＝サイコロに戻る、という判断は
///   呼び出し元が[armed]/[recording]の現在値を見て行う）。
///
/// タップの判定は[GestureDetector]ではなく[Listener]で生のポインタイベント
/// を直接見て行う。指を置いた場所と離した場所のポインタが一致すれば
/// タップとみなす（移動量やタイミングは問わない）。これは、画面全体を
/// 覆うスワイプ検出（[SwipeToCloseWrapper]）等、アプリ内の他のジェスチャーと
/// 同じアリーナで競合してタップが奪われることが実機（特にAndroid）で
/// 報告されたための対策で、[Listener]はアリーナに一切参加しないため、
/// アプリ内のどんなジェスチャーとも競合しない。
class PronunciationMicButton extends StatefulWidget {
  const PronunciationMicButton({
    super.key,
    required this.armed,
    required this.onTap,
    this.recording = false,
    this.size = 140,
    this.recordingColor = Colors.redAccent,
  });

  /// trueならマイクのアイコン（録音の構え）、falseならサイコロのアイコン
  /// （問題の表示・進行待ち）を表示する。
  final bool armed;

  final VoidCallback onTap;

  /// 実際に録音中かどうか（呼び出し元が管理）。trueの間は背景を[recordingColor]にする。
  final bool recording;

  /// ボタンの高さ（幅はこの2倍）。[TopicSpeakerTimerButton.size]と同じ規約。
  final double size;

  /// [recording]中の背景色。既定は赤（レイヤーⅤ短文と同じ）。
  /// レイヤーⅤ長文音読の「最短15秒はタップで止められない」表現では、
  /// 15秒経過後にオレンジへ切り替えて「もう止められる」ことを示す。
  final Color recordingColor;

  @override
  State<PronunciationMicButton> createState() => _PronunciationMicButtonState();
}

class _PronunciationMicButtonState extends State<PronunciationMicButton> {
  int? _activePointer;

  void _onPointerDown(PointerDownEvent event) {
    // 同時に複数の指で押された場合、最初の1本だけを追跡する。
    _activePointer ??= event.pointer;
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
    widget.onTap();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: widget.size * 2,
        height: widget.size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.rectangle,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          color: widget.recording ? widget.recordingColor : Colors.transparent,
        ),
        child: Icon(
          widget.armed ? Icons.mic_rounded : Icons.casino,
          size: widget.size,
          color: palette.onAccent,
        ),
      ),
    );
  }
}
