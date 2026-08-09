import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 履歴一覧で「旧形式」「未解析」などを示す小さなバッジ。
class HistoryFormatBadge extends StatelessWidget {
  const HistoryFormatBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: palette.cardBorder.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: palette.textOnCardSecondary),
      ),
    );
  }
}
