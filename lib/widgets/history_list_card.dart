import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/history_timestamp.dart';

/// 履歴一覧で使う共通のカード枠（タイムスタンプ行＋本文）。
class HistoryListCard extends StatelessWidget {
  const HistoryListCard({
    super.key,
    required this.createdAt,
    required this.languageCode,
    required this.children,
    this.badges = const [],
  });

  final DateTime createdAt;
  final String languageCode;
  final List<Widget> badges;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                formatHistoryTimestamp(createdAt, languageCode: languageCode),
                style: TextStyle(
                  fontSize: 12,
                  color: palette.textOnCardSecondary,
                ),
              ),
              const SizedBox(width: 8),
              ...badges,
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}
