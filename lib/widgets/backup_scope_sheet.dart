import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../main.dart' show appSettings;
import '../theme/app_colors.dart';

/// 起動画面「•••」のエクスポート／インポート対象範囲。
enum BackupScope { questionPromptsOnly, everything }

/// 起動画面「•••」のエクスポート／インポート共通の入口。「問題のみ」／
/// 「全て」のどちらを対象にするかを選ぶ（[TopicAddChoiceSheet]と同じ
/// トーンの選択シート）。
class BackupScopeSheet extends StatelessWidget {
  const BackupScopeSheet({super.key, required this.title});

  final String title;

  static Future<BackupScope?> show(
    BuildContext context, {
    required String title,
  }) {
    final palette = AppColors.current;
    return showModalBottomSheet<BackupScope>(
      context: context,
      backgroundColor: palette.cardFill,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => BackupScopeSheet(title: title),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: palette.textOnCardPrimary,
                ),
              ),
              const SizedBox(height: 4),
              _ChoiceRow(
                icon: Icons.assignment_rounded,
                label: '問題のみ'.tr(lang),
                subtitle: 'バックアップ範囲_説明_問題のみ'.tr(lang),
                onTap: () =>
                    Navigator.of(context).pop(BackupScope.questionPromptsOnly),
              ),
              _ChoiceRow(
                icon: Icons.all_inclusive_rounded,
                label: '全て'.tr(lang),
                subtitle: 'バックアップ範囲_説明_全て'.tr(lang),
                onTap: () => Navigator.of(context).pop(BackupScope.everything),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: palette.textOnCardPrimary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      color: palette.textOnCardPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: palette.textOnCardSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: palette.textOnCardSecondary),
          ],
        ),
      ),
    );
  }
}
