import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// osmPodの `EpisodeListFloatingJumpBar` の見た目を移植。半透明の白いカプセルに
/// シンプルな上下矢印だけを乗せた、枠線のないフローティングボタン。
class EpisodeJumpBar extends StatelessWidget {
  const EpisodeJumpBar({
    super.key,
    required this.onJumpToTop,
    required this.onJumpToBottom,
  });

  final VoidCallback onJumpToTop;
  final VoidCallback onJumpToBottom;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final barFill = palette.cardFill.withValues(alpha: 0.92);
    final iconColor = palette.mutedTextOn(barFill);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: barFill,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: palette.textOn(barFill).withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onJumpToTop,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.arrow_upward, size: 26, color: iconColor),
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: onJumpToBottom,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.arrow_downward, size: 26, color: iconColor),
            ),
          ),
        ],
      ),
    );
  }
}
