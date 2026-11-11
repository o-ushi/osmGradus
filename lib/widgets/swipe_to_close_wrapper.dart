import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// スワイプで前の画面に戻るための共通ラッパー（osm日日是好日と同じ）。
///
/// 下スワイプと左端からの右スワイプの両方で閉じる（osm日日是好日と同じ）。
///
/// [Listener] で生のポインタイベントだけを観測して速度を計算する（[GestureDetector] は
/// 使わない）。ドラッグ系の recognizer を使うと、内側の長押し・タップ・スクロールと
/// 同じジェスチャーアリーナで常に競合し、指のわずかな動きだけでドラッグ側が「勝ち」を
/// 宣言して内側の操作を強制終了させてしまう。[Listener] はアリーナに参加しないため、
/// 内側のどんなジェスチャー（タップ・長押し・スクロール・[Dismissible] など）も妨げない。
///
/// 閉じる判定の要点:
/// - 右スワイプは画面左端付近から始めたときだけ有効（親指の弧による誤検出を防ぐ）。
///   縦スクロールの途中でも、左端からの右スワイプなら戻れる。
/// - Android のジェスチャーナビ / iPadOS の端ジェスチャーは左端のポインタを
///   [PointerCancel] することがある。明確な右スワイプならキャンセル時も閉じる。
/// - [onClose] が無いときは [Navigator.maybePop] で戻る（[PopScope] の確認を尊重する）。
/// - [closeOnSwipeDown] のときは下スワイプでも閉じる。縦の一覧が先頭にあるときに始めた
///   下スワイプだけを数える。左右のスワイプを日送りに使う画面は [closeOnEdgeSwipe] を
///   false にして、右スワイプでは閉じない。
class SwipeToCloseWrapper extends StatefulWidget {
  const SwipeToCloseWrapper({
    super.key,
    required this.child,
    this.onClose,
    this.closeOnEdgeSwipe = true,
    this.closeOnSwipeDown = true,
  });

  final Widget child;

  /// 左端からの右スワイプで閉じるか。
  final bool closeOnEdgeSwipe;

  /// 下スワイプで閉じるか。
  final bool closeOnSwipeDown;

  /// 未指定の場合は [Navigator.maybePop] を実行する。
  final VoidCallback? onClose;

  @override
  State<SwipeToCloseWrapper> createState() => _SwipeToCloseWrapperState();
}

class _SwipeToCloseWrapperState extends State<SwipeToCloseWrapper> {
  static const double _velocityThreshold = 250;

  /// 右スワイプを受け付ける左端ゾーン幅（論理ピクセル）。
  /// [MediaQueryData.systemGestureInsets] / SafeArea 左余白の外側に足す。
  /// 32px だと Android の端バックや iPad の太い指で間欠的に外れるため広めに取る。
  static const double _rightSwipeEdgeWidth = 56;

  /// 経路上でこの量を超えて縦に動いていたら、右スワイプとしては扱わない。
  static const double _maxVerticalTravelForRightSwipe = 48;

  /// 速度が間欠的に低く出る端末向けの、右スワイプ距離フォールバック。
  static const double _rightSwipeMinDistance = 72;

  /// 始点→終点の変位で、右向きが縦向きよりどれだけ優勢であるべきか。
  static const double _netDominanceRatio = 1.25;

  /// 下スワイプの距離フォールバック（速度が低く出ても、これだけ下へ動けば閉じる）。
  static const double _downSwipeMinDistance = 96;

  /// 縦の一覧が先頭にあるか（下スワイプで閉じてよいか）。一覧がまだ動いていなければ先頭。
  bool _listAtTop = true;

  /// 指を置いた時点で一覧が先頭だったポインタ。
  final Set<int> _downFromTop = {};

  final Map<int, VelocityTracker> _trackers = {};
  final Map<int, Offset> _downPositions = {};
  final Map<int, Offset> _lastPositions = {};
  final Map<int, double> _horizontalTravel = {};
  final Map<int, double> _verticalTravel = {};

  void _handleClose() {
    if (widget.onClose != null) {
      widget.onClose!();
      return;
    }
    // 戻る先が無ければ何もしない。PopScope(canPop: false) なら確認側に任せる。
    Navigator.maybeOf(context)?.maybePop();
  }

  /// システム端ジェスチャー領域を含めた「左端スタート」判定の上限。
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
    final totalDelta = upPosition - downPosition;
    if (totalDelta.dy <= totalDelta.dx.abs() * _netDominanceRatio) return false;
    if (verticalTravel <= horizontalTravel) return false;
    return velocity.dy > _velocityThreshold * 2 ||
        (totalDelta.dy >= _downSwipeMinDistance && velocity.dy > 0);
  }

  bool _onScroll(ScrollNotification notification) {
    final metrics = notification.metrics;
    if (metrics.axis == Axis.vertical) {
      _listAtTop = metrics.pixels <= metrics.minScrollExtent;
    } else if (notification is ScrollEndNotification) {
      // 日送りなどで横に送ると、新しいページの一覧は先頭から始まる。
      _listAtTop = true;
    }
    return false;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_listAtTop) _downFromTop.add(event.pointer);
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

  void _onPointerUp(PointerUpEvent event) {
    final tracker = _trackers.remove(event.pointer);
    final downPosition = _downPositions.remove(event.pointer);
    final horizontalTravel = _horizontalTravel.remove(event.pointer) ?? 0;
    final verticalTravel = _verticalTravel.remove(event.pointer) ?? 0;
    _lastPositions.remove(event.pointer);
    final fromTop = _downFromTop.remove(event.pointer);
    if (tracker == null || downPosition == null) return;

    // 最終位置を速度計算に含め、Android 等の疎な move ストリームでも速度が
    // 落ちにくくする。
    tracker.addPosition(event.timeStamp, event.position);
    final velocity = tracker.getVelocity().pixelsPerSecond;

    if (widget.closeOnSwipeDown &&
        fromTop &&
        _isDownSwipe(
          downPosition: downPosition,
          upPosition: event.position,
          horizontalTravel: horizontalTravel,
          verticalTravel: verticalTravel,
          velocity: velocity,
        )) {
      _handleClose();
      return;
    }

    if (widget.closeOnEdgeSwipe &&
        _isRightSwipe(
          downPosition: downPosition,
          upPosition: event.position,
          horizontalTravel: horizontalTravel,
          verticalTravel: verticalTravel,
          velocity: velocity,
        )) {
      _handleClose();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    // システムが左端ジェスチャーを奪うと up の代わりに cancel が来る。
    // すでに明確な右スワイプなら閉じる。
    //
    // Navigator 経路では、システムの戻るが既に pop している可能性があるため、
    // カスタム [onClose] があるときだけ即閉じる。
    // それ以外は次フレームでまだ pop できる場合だけ閉じる（二重に戻らない）。
    final tracker = _trackers.remove(event.pointer);
    final downPosition = _downPositions.remove(event.pointer);
    final lastPosition = _lastPositions.remove(event.pointer) ?? event.position;
    final horizontalTravel = _horizontalTravel.remove(event.pointer) ?? 0;
    final verticalTravel = _verticalTravel.remove(event.pointer) ?? 0;
    _downFromTop.remove(event.pointer);

    // 右スワイプで閉じない画面では、システムが奪ったポインタでも閉じない。
    if (!widget.closeOnEdgeSwipe) return;
    if (tracker == null || downPosition == null) return;

    // cancel の timeStamp が move より古い／同一だと VelocityTracker が
    // 壊れることがあるので、既存サンプルの速度を使い、足りなければ距離で判定する。
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final navigator = Navigator.maybeOf(context);
      if (navigator != null && navigator.canPop()) navigator.maybePop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: widget.closeOnSwipeDown
          ? NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: widget.child,
            )
          : widget.child,
    );
  }
}
