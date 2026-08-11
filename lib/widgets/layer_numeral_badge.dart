import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'button_action_hint.dart';

/// 起動画面の[LayerListTile]・[AppHeader]と同じ「色付き丸＋ローマ数字」。
///
/// - [LayerNumeralBadge] … 詳細画面の次レイヤー遷移（タップ可・大きめ）
/// - [LayerNumeralIcon] … 一覧ヘッダー／進捗セル用の縮小表示（タップなし）
class LayerNumeralBadge extends StatelessWidget {
  const LayerNumeralBadge({
    super.key,
    required this.layerIndex,
    required this.onTap,
    this.tooltip,
    this.size = 56,
    this.hintTapText,
  });

  /// 0=Ⅰ, 1=Ⅱ, 2=Ⅲ, 3=Ⅳ, 4=Ⅴ。
  final int layerIndex;
  final VoidCallback onTap;
  final String? tooltip;
  final double size;

  /// 非nullの場合、ダブルタップで「タップ：[hintTapText]／長押し：なし」の
  /// ヒントを表示する（[GhostPill.hintTapText]と同じStep 7の
  /// [ButtonActionHint]基盤。同じトレードオフ・理由も
  /// [GhostPill.hintTapText]のコメントを参照。このボタンに長押し機能はない）。
  final String? hintTapText;

  static const numerals = ['Ⅰ', 'Ⅱ', 'Ⅲ', 'Ⅳ', 'Ⅴ'];

  @override
  Widget build(BuildContext context) {
    final badge = SizedBox(
      height: 56,
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          onDoubleTap: hintTapText == null
              ? null
              : () => ButtonActionHint.show(context, tapText: hintTapText!),
          behavior: HitTestBehavior.opaque,
          child: LayerNumeralIcon(layerIndex: layerIndex, size: size),
        ),
      ),
    );
    if (tooltip == null) return badge;
    return Tooltip(message: tooltip!, child: badge);
  }
}

/// 起動画面タイルと同じ見た目の縮小アイコン（非インタラクティブ）。
///
/// [filled]がtrueなら起動画面どおり塗りつぶし、falseなら[AppHeader]の
/// 非選択タブと同じ枠線のみ（未実施の進捗表示に使う）。
class LayerNumeralIcon extends StatelessWidget {
  const LayerNumeralIcon({
    super.key,
    required this.layerIndex,
    this.size = 22,
    this.filled = true,
  });

  /// 0=Ⅰ, 1=Ⅱ, 2=Ⅲ, 3=Ⅳ, 4=Ⅴ。
  final int layerIndex;
  final double size;

  /// true=塗りつぶし（実施済／ヘッダー）、false=枠線のみ（未実施）。
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final color = palette.layerColors[layerIndex];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? color : Colors.transparent,
        shape: BoxShape.circle,
        border: filled ? null : Border.all(color: color, width: 1.5),
      ),
      child: Text(
        LayerNumeralBadge.numerals[layerIndex],
        style: TextStyle(
          color: filled ? palette.onFill(color) : color,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.45,
          height: 1,
        ),
      ),
    );
  }
}
