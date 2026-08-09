import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/history_timestamp.dart';
import 'history_format_badge.dart';

/// 履歴詳細画面の先頭行（日時＋任意の「旧形式」「未解析」バッジ）。
class HistoryDetailHeader extends StatelessWidget {
  const HistoryDetailHeader({
    super.key,
    required this.createdAt,
    required this.languageCode,
    this.badgeLabels = const [],
  });

  final DateTime createdAt;
  final String languageCode;
  final List<String> badgeLabels;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return Row(
      children: [
        Text(
          formatHistoryDetailTimestamp(createdAt, languageCode: languageCode),
          style: TextStyle(
            fontSize: 12,
            color: palette.textOnSubpageSecondary,
          ),
        ),
        for (final label in badgeLabels) ...[
          const SizedBox(width: 8),
          HistoryFormatBadge(label: label),
        ],
      ],
    );
  }
}
