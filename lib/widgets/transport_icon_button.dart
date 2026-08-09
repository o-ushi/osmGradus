import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// [GenkiTransportRow]の各ボタン（アイコンのみ、高さ56・角丸28）を切り出した
/// 公開版。`borderless: true`（余白ゼロ・背景と枠線は透明・アイコンを
/// 目一杯大きく表示）は、レイヤーⅡ〜Ⅳの再生/リセット/送信ボタンと同じ
/// 見た目を、他の用途（長文読解の操作バー等）でも流用するために公開している。
class TransportIconButton extends StatelessWidget {
  const TransportIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.visible,
    required this.onTap,
    this.onLongPress,
    this.highlighted = false,
    this.highlightColor,
    this.borderless = false,
    this.enabled = true,
  });

  final IconData icon;
  final String tooltip;
  final bool visible;
  final VoidCallback? onTap;

  /// 非nullの場合、長押しでこれを呼ぶ（例：確認画面を経由せず直接AIへ進む
  /// 「近道」操作）。
  final VoidCallback? onLongPress;

  /// trueの間は青地（または[highlightColor]）に白アイコンで強調する。
  final bool highlighted;

  /// 強調時の背景色。null のときは [AppPalette.accentColor]。
  final Color? highlightColor;

  /// 枠線なし・背景透明で、アイコンを可能な限り大きく表示する。
  final bool borderless;

  /// falseの間は[visible]がfalseのときと同じく背景色に同化させて隠し、
  /// タップも無効にする（枠自体は確保したまま、他のゴーストピルと同じ
  /// 見た目で「今は使えない」ことを示す）。
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final shown = visible && enabled;
    final emphasize = shown && highlighted;
    final accent = highlightColor ?? palette.accentColor;
    final sceneOutline = palette.textOnScenePrimary;
    final foreground = !shown
        ? palette.scene
        : (emphasize ? palette.onFill(accent) : sceneOutline);
    final fill = emphasize ? accent : Colors.transparent;
    final border = !shown
        ? palette.scene
        : (emphasize ? accent : sceneOutline);
    final resolvedIconSize = borderless ? 56.0 : 30.0;
    return Tooltip(
      message: tooltip,
      // 長押しをonLongPress側の操作に譲る（Tooltip既定のlongPressトリガーと
      // 競合してヒットテストが不安定になるのを防ぐ）。
      triggerMode: onLongPress != null ? TooltipTriggerMode.manual : null,
      child: IgnorePointer(
        ignoring: !shown,
        child: ExcludeSemantics(
          excluding: !shown,
          child: GestureDetector(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Container(
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: borderless && !emphasize ? Colors.transparent : fill,
                borderRadius: BorderRadius.circular(28),
                border: borderless
                    ? null
                    : Border.all(color: border, width: 1.5),
              ),
              child: borderless
                  ? SizedBox(
                      height: 56,
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: Icon(
                          icon,
                          size: resolvedIconSize,
                          color: foreground,
                        ),
                      ),
                    )
                  : Icon(icon, size: resolvedIconSize, color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}
