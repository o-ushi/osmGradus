import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../main.dart' show appSettings;
import '../theme/app_colors.dart';

/// ダブルタップで「タップ：／長押し：」の意味を一時的に表示する共通基盤（Step 7）。
///
/// [ButtonActionHintOverlay]を`MaterialApp.builder`直下に置き、各ボタン
/// （[GhostPill]・[TransportIconButton]・[LayerNumeralBadge]等）は
/// ダブルタップ時に[ButtonActionHint.show]を呼ぶだけでよい。
/// 表示中に他の操作（別ボタンへのポインタ操作・スクロール開始・同じボタンの
/// 通常タップ等）が入るとその操作自体は妨げず即座に消える。無操作の場合の
/// 消え方は設定（[AppSettings.buttonHintPersistUntilNextAction]・
/// [AppSettings.buttonHintDisplaySeconds]、Step 8）に従う：既定はOFF＝
/// 3秒で自動的に消え、ONにすると時間では消えず次のアクションまで残る。
abstract final class ButtonActionHint {
  static ButtonActionHintOverlayState? _overlayState;

  static void attach(ButtonActionHintOverlayState state) {
    _overlayState = state;
  }

  static void detach(ButtonActionHintOverlayState state) {
    if (identical(_overlayState, state)) _overlayState = null;
  }

  /// [anchorContext]（対象ボタン自身のcontext）の直下にヒントを表示する。
  static void show(
    BuildContext anchorContext, {
    required String tapText,
    String? longPressText,
  }) {
    final box = anchorContext.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    final anchorRect = box.localToGlobal(Offset.zero) & box.size;
    _overlayState?.showHint(
      anchorRect: anchorRect,
      tapText: tapText,
      longPressText: longPressText,
    );
  }

  /// 画面遷移など、ポインタ操作を伴わない離脱でも消したいときに呼ぶ
  /// （[ButtonActionHintNavigatorObserver]から使う）。
  static void hide() => _overlayState?.hideHint();
}

/// [MaterialApp.builder]の直下に置く、ヒントの実描画・自動消去を担うオーバーレイ。
class ButtonActionHintOverlay extends StatefulWidget {
  const ButtonActionHintOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<ButtonActionHintOverlay> createState() =>
      ButtonActionHintOverlayState();
}

class ButtonActionHintOverlayState extends State<ButtonActionHintOverlay> {
  Rect? _anchorRect;
  String? _tapText;
  String? _longPressText;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    ButtonActionHint.attach(this);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onGlobalPointerEvent);
  }

  @override
  void dispose() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(
      _onGlobalPointerEvent,
    );
    ButtonActionHint.detach(this);
    _timer?.cancel();
    super.dispose();
  }

  /// アプリ内のどのポインタ操作も、ヒットテストの結果に関わらずここへ届く
  /// （[GestureBinding.pointerRouter.addGlobalRoute]）。別ボタンのタップ・
  /// スクロール開始・同じボタンの通常タップ、いずれも先頭は
  /// [PointerDownEvent]のため、これだけ見ればよい。
  void _onGlobalPointerEvent(PointerEvent event) {
    if (event is! PointerDownEvent || _anchorRect == null) return;
    hideHint();
  }

  void showHint({
    required Rect anchorRect,
    required String tapText,
    String? longPressText,
  }) {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _anchorRect = anchorRect;
      _tapText = tapText;
      _longPressText = longPressText;
    });
    // 設定（Step 8）を毎回ここで読むことで、設定変更が次に出すヒントへ
    // 即座に反映される（画面を開き直す必要がない）。
    if (appSettings.buttonHintPersistUntilNextAction) return;
    _timer = Timer(
      Duration(seconds: appSettings.buttonHintDisplaySeconds),
      hideHint,
    );
  }

  void hideHint() {
    _timer?.cancel();
    _timer = null;
    if (_anchorRect == null) return;
    setState(() => _anchorRect = null);
  }

  @override
  Widget build(BuildContext context) {
    final rect = _anchorRect;
    return Stack(
      // 既定のStackFit.looseだとwidget.child（アプリ本体）へ緩い制約が
      // 渡ってしまう。アプリ本体はこのオーバーレイが無かった場合と全く
      // 同じ、画面いっぱいのタイト制約で描画されるべきなのでexpandにする。
      fit: StackFit.expand,
      children: [
        widget.child,
        if (rect != null)
          _HintBubble(
            anchorRect: rect,
            tapText: _tapText!,
            longPressText: _longPressText,
          ),
      ],
    );
  }
}

/// 画面遷移でヒントを消すための[NavigatorObserver]（[MaterialApp.navigatorObservers]へ渡す）。
/// ほとんどの遷移はタップ操作起点で[ButtonActionHintOverlayState]の
/// グローバルポインタ監視がすでに消しているが、Chrome AIから戻ったときの
/// 自動遷移などポインタ操作を伴わない場合の保険として持つ。
class ButtonActionHintNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      ButtonActionHint.hide();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      ButtonActionHint.hide();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      ButtonActionHint.hide();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      ButtonActionHint.hide();
}

class _HintBubble extends StatelessWidget {
  const _HintBubble({
    required this.anchorRect,
    required this.tapText,
    this.longPressText,
  });

  final Rect anchorRect;
  final String tapText;
  final String? longPressText;

  static const _width = 240.0;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final lang = appSettings.language;
    final screenSize = MediaQuery.of(context).size;

    final maxLeft = (screenSize.width - _width - 12.0).clamp(
      12.0,
      double.infinity,
    );
    final left = (anchorRect.center.dx - _width / 2).clamp(12.0, maxLeft);
    const bubbleHeight = 72.0;
    final preferredTop = anchorRect.bottom + 8;
    final fitsBelow = preferredTop + bubbleHeight <= screenSize.height - 12;
    final top = fitsBelow
        ? preferredTop
        : (anchorRect.top - bubbleHeight - 8).clamp(
            12.0,
            screenSize.height - 12.0,
          );

    final longPress = longPressText ?? 'ボタンヒント_長押しなし'.tr(lang);
    final message =
        '${'ボタンヒント_タップ'.trFmt(lang, [tapText])}\n'
        '${'ボタンヒント_長押し'.trFmt(lang, [longPress])}';

    return Positioned(
      left: left,
      top: top,
      width: _width,
      child: IgnorePointer(
        child: Semantics(
          liveRegion: true,
          label: message,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: palette.cardFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.cardBorder),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: palette.textOnCardPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
