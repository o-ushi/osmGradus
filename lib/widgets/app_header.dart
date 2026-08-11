import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 全レイヤー共通のヘッダー。「Ⅰ」〜「Ⅴ」のアイコンボタンを常時表示し、
/// タップで即座に（アニメーションなしで）該当レイヤーへ切り替える。
/// どのボタンを長押ししても（対象レイヤーによらず）[onLongPress]を呼び、
/// スタート画面（起動画面）へジャンプする導線に使う。
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({
    super.key,
    required this.currentIndex,
    required this.onSelect,
    this.onLongPress,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;

  /// 非nullの場合、いずれかのボタンの長押しでこれを呼ぶ（スタート画面へ戻る導線）。
  final VoidCallback? onLongPress;

  static const List<String> numerals = ['Ⅰ', 'Ⅱ', 'Ⅲ', 'Ⅳ', 'Ⅴ'];

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return Material(
      color: palette.cardFill,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: preferredSize.height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(numerals.length, (index) {
              return _LayerIconButton(
                label: numerals[index],
                isActive: index == currentIndex,
                color: palette.layerColors[index],
                onTap: () => onSelect(index),
                onLongPress: onLongPress,
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _LayerIconButton extends StatelessWidget {
  const _LayerIconButton({
    required this.label,
    required this.isActive,
    required this.color,
    required this.onTap,
    this.onLongPress,
  });

  final String label;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      // アニメーションを挟まず即時に見た目を切り替える（低スペック端末対策）。
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? color : palette.cardFill,
          shape: BoxShape.circle,
          border: Border.all(color: color, width: isActive ? 0 : 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? palette.onFill(color) : color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
