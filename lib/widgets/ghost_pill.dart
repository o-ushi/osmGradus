import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'button_action_hint.dart';

/// 位置・サイズは確保したまま、`visible: false`のときは背景色に同化させて
/// 実質非表示にし、タップにも反応しないようにするピル型ボタン。
/// レイヤーによっては使わない機能ボタンの「予約席」として使う
/// （`if`で丸ごと外すと、隣接する常時表示ボタンの位置がレイヤーごとにズレるため）。
class GhostPill extends StatelessWidget {
  const GhostPill({
    super.key,
    this.label,
    this.icon,
    this.child,
    this.onTap,
    this.onLongPress,
    this.tooltip,
    this.visible = true,
    this.active = false,
    this.activeFill,
    this.activeForeground,
    this.horizontalPadding = 18,
    this.showBorder = true,
    this.labelFontSize = 18,
    this.iconSize = 24,
    this.height = 56,
    this.enabled = true,
    this.hintTapText,
    this.hintLongPressText,
  });

  final String? label;
  final IconData? icon;

  /// 非nullの場合、[icon]・[label]より優先してこの内容を描画する
  /// （呼び出し側が既に配色済みの、単色アイコンでは表現できない見た目
  /// （例：色付き丸＋白いチェック）を差し込みたいときに使う）。
  final Widget? child;

  final VoidCallback? onTap;

  /// 非nullの場合、長押しでこれを呼ぶ（例：使い方シートを開く）。
  /// 指定時は[tooltip]によるTooltipの長押し表示と競合するため、
  /// Tooltipでのラップ自体を省く（長押しの結果がより詳しい内容になるため）。
  final VoidCallback? onLongPress;
  final String? tooltip;
  final bool visible;

  /// ピル内側の左右パディング。文字数が多いラベル（例：「15+60」）だけ
  /// 狭くして、FittedBoxの縮小を緩和したいときに使う。
  /// アイコン／絵文字を枠いっぱいに大きくしたいときは0にする。
  final double horizontalPadding;

  /// falseのとき枠線を描かない（レイヤーⅡの解答例アイコンなど、枠なし用）。
  final bool showBorder;

  /// [label]表示時の基準フォントサイズ。[FittedBox]で枠に収まるよう縮小される。
  /// 枠いっぱいまで大きくしたい絵文字などでは高さ相当（例: 56）を渡す。
  final double labelFontSize;

  /// [icon]表示時のサイズ。枠いっぱいに大きくしたいときは高さ相当（例: 48）を渡す。
  final double iconSize;

  /// visible時、選択中であることを[AppPalette.cardAccent]の塗りつぶしで示す
  /// （レイヤーⅢのタイマープリセットのように実際に選択できるピルで使う）。
  final bool active;

  /// active時の塗り色・前景色を[AppPalette.cardAccent]/[AppPalette.onAccent]から
  /// 差し替えたい場合に指定する（例：レイヤーⅣの「＋」→評価結果一覧ボタンは
  /// 選択色ではなく[AppPalette.accentColor]の青で「結果あり」を示す）。
  final Color? activeFill;
  final Color? activeForeground;

  /// ピルの高さ（枠なし・アイコンのみモードではアイコンもこの高さいっぱいまで
  /// 拡大される）。既存呼び出し元との見た目互換のため既定は56。
  final double height;

  /// falseの間はvisibleのまま（枠・アイコンは見えるが）タップに反応せず、
  /// 半透明で無効状態を示す。
  final bool enabled;

  /// 非nullの場合、ダブルタップで「タップ：[hintTapText]／長押し：
  /// [hintLongPressText]（未指定なら「なし」）」のヒントを表示する
  /// （Step 7の[ButtonActionHint]基盤）。[onTap]と同じ[GestureDetector]に
  /// [GestureDetector.onDoubleTap]として載せるため、指定した場合のみ単タップの
  /// 発火がFlutter既定のダブルタップ判定分（約300ms）遅れる。
  ///
  /// これは意図的なトレードオフ：多くの対象ボタン（「問題作成」＝ダイアログ
  /// 表示、「訳を付ける」「単語帳」「II」＝画面遷移）は[onTap]自体が
  /// ダイアログ表示・画面遷移などボタンを画面から消す動作のため、もし単タップ
  /// を即座に発火させてしまうと1回目のタップでボタンが消え、2回目のタップが
  /// 同じボタンへ絶対に届かずダブルタップが検出できなくなる
  /// （実際にこの問題が起きたため、自前の「即座に発火＋事後判定」方式から
  /// 変更した）。[hintTapText]が[null]のボタンは従来どおり[onDoubleTap]が
  /// 付かず、単タップの反応速度は変わらない。
  final String? hintTapText;
  final String? hintLongPressText;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final resolvedActiveFill = activeFill ?? palette.cardAccent;
    final resolvedActiveForeground =
        activeForeground ?? palette.onFill(resolvedActiveFill);
    final sceneOutline = palette.textOnScenePrimary;
    final foreground = !visible
        ? palette.scene
        : (active ? resolvedActiveForeground : sceneOutline);
    final fill = active && visible ? resolvedActiveFill : palette.scene;
    final Color borderColor;
    if (!visible || !showBorder) {
      // 非表示時は背景に同化。showBorder:falseでも枠線を出さない。
      borderColor = palette.scene;
    } else if (active) {
      borderColor = resolvedActiveFill;
    } else {
      borderColor = sceneOutline;
    }
    final content = Container(
      height: height,
      constraints: BoxConstraints(minWidth: showBorder ? height : 0),
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: showBorder
            ? fill
            : (active && visible ? fill : Colors.transparent),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: borderColor,
          width: showBorder && visible ? 1.5 : 0,
        ),
      ),
      child:
          child ??
          (icon != null
              ? (!showBorder && horizontalPadding == 0
                    ? SizedBox(
                        height: height,
                        width: double.infinity,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: Icon(icon, size: height, color: foreground),
                        ),
                      )
                    : Icon(icon, size: iconSize, color: foreground))
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label!,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: labelFontSize,
                      fontWeight: FontWeight.bold,
                      color: foreground,
                      height: 1,
                    ),
                  ),
                )),
    );
    final pill = IgnorePointer(
      ignoring: !visible || !enabled,
      child: ExcludeSemantics(
        excluding: !visible || !enabled,
        child: Opacity(
          opacity: enabled ? 1 : 0.38,
          child: GestureDetector(
            onTap: onTap,
            onLongPress: onLongPress,
            onDoubleTap: hintTapText == null
                ? null
                : () => ButtonActionHint.show(
                    context,
                    tapText: hintTapText!,
                    longPressText: hintLongPressText,
                  ),
            child: content,
          ),
        ),
      ),
    );
    if (tooltip == null) return pill;
    return Tooltip(
      message: tooltip!,
      // 長押しをonLongPress側の操作に譲る（Tooltip既定のlongPressトリガーと
      // 競合してヒットテストが不安定になるのを防ぐ）。
      triggerMode: onLongPress != null ? TooltipTriggerMode.manual : null,
      child: pill,
    );
  }
}
