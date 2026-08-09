import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../theme/app_colors.dart';

/// 「長文読解」タップ時、長文一覧に保存済みの長文があるときだけ出す、
/// 「一覧から選ぶ」か「新規作成」かの選択シート（[TopicAddChoiceSheet]と
/// 同じ見た目・構造。osmCogitoの`CogitoNewSessionChoiceSheet`と同じ役割を
/// 移植した）。
enum LongArticleStartMode {
  /// 長文一覧から選んだ長文でそのまま読解を始める（キーワード入力・生成を
  /// スキップする）。
  fromSavedArticle,

  /// 通常どおりキーワード入力から始める。
  newArticle,
}

class LongArticleStartChoiceSheet extends StatelessWidget {
  const LongArticleStartChoiceSheet({super.key});

  static Future<LongArticleStartMode?> show(BuildContext context) {
    final palette = AppColors.current;
    return showModalBottomSheet<LongArticleStartMode>(
      context: context,
      backgroundColor: palette.cardFill,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const LongArticleStartChoiceSheet(),
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
                '長文読解_開始選択_タイトル'.tr(lang),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: palette.textOnCardPrimary,
                ),
              ),
              const SizedBox(height: 4),
              _ChoiceRow(
                icon: Icons.menu_book_outlined,
                label: '長文読解_開始選択_一覧から選ぶ'.tr(lang),
                subtitle: '長文読解_開始選択_一覧から選ぶ_説明'.tr(lang),
                onTap: () => Navigator.of(
                  context,
                ).pop(LongArticleStartMode.fromSavedArticle),
              ),
              _ChoiceRow(
                icon: Icons.auto_awesome_rounded,
                label: '長文読解_開始選択_新規作成'.tr(lang),
                subtitle: '長文読解_開始選択_新規作成_説明'.tr(lang),
                onTap: () =>
                    Navigator.of(context).pop(LongArticleStartMode.newArticle),
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
