import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 戻るボタン「<」を使わず、下スワイプ or 右スワイプで画面を閉じるための共通ラッパー。
/// 各詳細画面のbodyをこれで包むことで、osmファミリー共通の操作感を実現する。
///
/// [Listener]で生のポインタイベントだけを観測して速度を計算する（[GestureDetector]は
/// 使わない）。[GestureDetector]のドラッグ系recognizerを使うと、このラッパーの
/// 内側にある長押しボタン（レイヤーⅤのマイクボタン等）と同じジェスチャーアリーナで
/// 常に競合してしまい、指を握り込む・わずかに動かすといった微小な動きだけで
/// ドラッグ側が「勝ち」を宣言し、長押しが`onLongPressCancel`で強制終了させられる
/// （さらに、その解放速度が閾値を超えていると[Navigator.pop]まで呼ばれてしまい、
/// レイヤーⅤであれば録音中に画面ごと閉じてセッションが消える）。[Listener]は
/// アリーナに参加しないため、内側のどんなジェスチャー（タップ・長押し・スクロール等）
/// も一切妨げない。
///
/// 閉じる判定の要点:
/// - 内側の[Scrollable]に触れた指の動き（実スクロール・端のオーバースクロール）では
///   閉じない。スクロールと「下スワイプで閉じる」の取り違えを防ぐ。
/// - 右スワイプは画面左端付近から始めたときだけ有効（親指弧の誤検出防止）。
///   スクロール中に閉じたいときは左端からの右スワイプを使う（スクロール拒否の対象外）。
/// - Androidのジェスチャーナビ / iPadOSの端ジェスチャは左端ポインタを
///   [PointerCancel]することがある。明確な右スワイプならキャンセル時も閉じる。
class SwipeToCloseWrapper extends StatefulWidget {
  const SwipeToCloseWrapper({super.key, required this.child, this.onClose});

  final Widget child;

  /// 未指定の場合は [Navigator.pop] を実行する。
  final VoidCallback? onClose;

  @override
  State<SwipeToCloseWrapper> createState() => _SwipeToCloseWrapperState();
}

class _SwipeToCloseWrapperState extends State<SwipeToCloseWrapper> {
  static const double _velocityThreshold = 250;

  /// 右スワイプを受け付ける左端ゾーン幅（論理ピクセル）。
  /// [MediaQuery.systemGestureInsets] / SafeArea 左余白の外側に足す。
  /// 32pxだとAndroid端バックやiPadの太い指で間欠的に外れるため広めに取る。
  static const double _rightSwipeEdgeWidth = 56;

  /// 経路上でこの量を超えて縦に動いていたら、右スワイプとしては扱わない。
  static const double _maxVerticalTravelForRightSwipe = 48;

  /// 速度が間欠的に低く出る端末向けの、右スワイプ距離フォールバック。
  static const double _rightSwipeMinDistance = 72;

  /// 始点→終点の変位で、閉じる向きがもう一方の軸よりどれだけ優勢であるべきか。
  static const double _netDominanceRatio = 1.25;

  final Map<int, VelocityTracker> _trackers = {};
  final Map<int, Offset> _downPositions = {};
  final Map<int, Offset> _lastPositions = {};
  final Map<int, double> _horizontalTravel = {};
  final Map<int, double> _verticalTravel = {};

  /// 現在の指の動きのあいだに、内側のScrollableが反応したか
  /// （中身のスクロール、または端でのオーバースクロール）。
  /// 下スワイプの誤検出防止にのみ使う（右スワイプは対象外）。
  bool _scrollInteracted = false;

  void _handleClose() {
    if (widget.onClose != null) {
      widget.onClose!();
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  /// システム端ジェスチャ領域を含めた「左端スタート」判定上限。
  double _leftEdgeLimit(BuildContext context) {
    final mq = MediaQuery.of(context);
    final contestedLeft = math.max(
      mq.systemGestureInsets.left,
      mq.padding.left,
    );
    return contestedLeft + _rightSwipeEdgeWidth;
  }

  bool _isRightSwipeGeometry({
    required Offset downPosition,
    required Offset upPosition,
    required double horizontalTravel,
    required double verticalTravel,
  }) {
    final startedFromLeftEdge = downPosition.dx <= _leftEdgeLimit(context);
    if (!startedFromLeftEdge) return false;
    if (verticalTravel > _maxVerticalTravelForRightSwipe) return false;

    final totalDelta = upPosition - downPosition;
    if (totalDelta.dx <= totalDelta.dy.abs() * _netDominanceRatio) return false;
    if (horizontalTravel <= verticalTravel) return false;
    return true;
  }

  bool _isRightSwipe({
    required Offset downPosition,
    required Offset upPosition,
    required double horizontalTravel,
    required double verticalTravel,
    required Offset velocity,
    bool relaxVelocity = false,
  }) {
    if (!_isRightSwipeGeometry(
      downPosition: downPosition,
      upPosition: upPosition,
      horizontalTravel: horizontalTravel,
      verticalTravel: verticalTravel,
    )) {
      return false;
    }

    final totalDelta = upPosition - downPosition;

    // 通常: 速度十分、または距離十分＋速度がゼロでない（疎サンプリング対策）。
    if (velocity.dx > _velocityThreshold ||
        (totalDelta.dx >= _rightSwipeMinDistance &&
            velocity.dx > _velocityThreshold * 0.35)) {
      return true;
    }

    // PointerCancel 時は VelocityTracker が壊れることがあるため、
    // 幾何条件＋十分な距離だけで閉じる。
    return relaxVelocity && totalDelta.dx >= _rightSwipeMinDistance;
  }

  bool _isDownSwipe({
    required Offset downPosition,
    required Offset upPosition,
    required double horizontalTravel,
    required double verticalTravel,
    required Offset velocity,
  }) {
    if (_scrollInteracted) return false;
    final totalDelta = upPosition - downPosition;
    return totalDelta.dy > totalDelta.dx.abs() * _netDominanceRatio &&
        verticalTravel >= horizontalTravel &&
        velocity.dy > _velocityThreshold;
  }

  void _onPointerDown(PointerDownEvent event) {
    _scrollInteracted = false;
    (_trackers[event.pointer] = VelocityTracker.withKind(
      event.kind,
    )).addPosition(event.timeStamp, event.position);
    _downPositions[event.pointer] = event.position;
    _lastPositions[event.pointer] = event.position;
    _horizontalTravel[event.pointer] = 0;
    _verticalTravel[event.pointer] = 0;
  }

  void _onPointerMove(PointerMoveEvent event) {
    _trackers[event.pointer]?.addPosition(event.timeStamp, event.position);
    final last = _lastPositions[event.pointer];
    if (last != null) {
      final step = event.position - last;
      _horizontalTravel[event.pointer] =
          (_horizontalTravel[event.pointer] ?? 0) + step.dx.abs();
      _verticalTravel[event.pointer] =
          (_verticalTravel[event.pointer] ?? 0) + step.dy.abs();
    }
    _lastPositions[event.pointer] = event.position;
  }

  void _finishPointer({
    required int pointer,
    required Duration timeStamp,
    required Offset position,
  }) {
    final tracker = _trackers.remove(pointer);
    final downPosition = _downPositions.remove(pointer);
    final horizontalTravel = _horizontalTravel.remove(pointer) ?? 0;
    final verticalTravel = _verticalTravel.remove(pointer) ?? 0;
    _lastPositions.remove(pointer);
    if (tracker == null || downPosition == null) return;

    // 最終位置を速度計算に含め、Android等の疎な move ストリームでも速度が
    // 落ちにくくする。
    tracker.addPosition(timeStamp, position);
    final velocity = tracker.getVelocity().pixelsPerSecond;

    final isRight = _isRightSwipe(
      downPosition: downPosition,
      upPosition: position,
      horizontalTravel: horizontalTravel,
      verticalTravel: verticalTravel,
      velocity: velocity,
    );
    final isDown = _isDownSwipe(
      downPosition: downPosition,
      upPosition: position,
      horizontalTravel: horizontalTravel,
      verticalTravel: verticalTravel,
      velocity: velocity,
    );

    if (isRight || isDown) {
      _handleClose();
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _finishPointer(
      pointer: event.pointer,
      timeStamp: event.timeStamp,
      position: event.position,
    );
  }

  void _onPointerCancel(PointerCancelEvent event) {
    // システムが左端ジェスチャを奪うと up の代わりに cancel が来る。
    // すでに明確な右スワイプなら閉じる（下スワイプは誤爆しやすいので cancel では閉じない）。
    //
    // Navigator.pop 経路では、システム戻るが既に pop している可能性があるため
    // カスタム [onClose] があるときだけ即閉じる（MainShell 等）。
    // それ以外は次フレームでまだ pop 可能なら閉じる。
    final tracker = _trackers.remove(event.pointer);
    final downPosition = _downPositions.remove(event.pointer);
    final lastPosition = _lastPositions.remove(event.pointer) ?? event.position;
    final horizontalTravel = _horizontalTravel.remove(event.pointer) ?? 0;
    final verticalTravel = _verticalTravel.remove(event.pointer) ?? 0;

    if (tracker == null || downPosition == null) return;

    // cancel の timeStamp が move より古い／同一だと VelocityTracker が
    // 壊れることがあるので、既存サンプルの速度を使い、足りなければ距離で判定。
    final velocity = tracker.getVelocity().pixelsPerSecond;
    final shouldCloseOnCancel = _isRightSwipe(
      downPosition: downPosition,
      upPosition: lastPosition,
      horizontalTravel: horizontalTravel,
      verticalTravel: verticalTravel,
      velocity: velocity,
      relaxVelocity: true,
    );

    if (!shouldCloseOnCancel) return;

    if (widget.onClose != null) {
      widget.onClose!();
      return;
    }

    // システム戻ると二重 pop しないよう、フレーム後にまだ残っていれば閉じる。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  bool _onScrollNotification(ScrollNotification notification) {
    // 実スクロール、または端でのオーバースクロール（先頭での下フリックなど）の
    // どちらも「スクロール操作」とみなして下スワイプでは閉じない。
    // 右スワイプ（左端スタート）はスクロール中の「戻る」手段なので対象外。
    //
    // ただし、中身が画面に収まっていてスクロール可能範囲が無い
    // （maxScrollExtent <= minScrollExtent）Scrollableは対象外にする。
    // BouncingScrollPhysics等では、スクロール範囲が無くても指を動かすと
    // ラバーバンド分のOverscrollNotificationが飛んでしまい、実際には
    // 何もスクロールしていないのに「スクロール操作」とみなされて下スワイプ
    // での閉じる判定が誤って無効化される（本文が短く、SingleChildScrollView
    // が実質スクロール不要なケースで頻発する）。
    final metrics = notification.metrics;
    if (metrics.maxScrollExtent <= metrics.minScrollExtent) return false;

    if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null &&
        (notification.scrollDelta?.abs() ?? 0) > 0) {
      _scrollInteracted = true;
    } else if (notification is OverscrollNotification &&
        notification.dragDetails != null) {
      _scrollInteracted = true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: widget.child,
      ),
    );
  }
}
