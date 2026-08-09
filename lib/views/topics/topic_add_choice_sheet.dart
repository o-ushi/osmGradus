import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../theme/app_colors.dart';

/// お題を「AIで追加」「自分で追加」するか、JSONファイルで
/// 「ファイルをインポート」「エクスポート」するか（Step 10 / Step 13）。
enum TopicAddMethod { ai, manual, jsonImport, jsonExport }

/// レイヤーⅡ・Ⅲ・Ⅳの「＋」タップ共通の入口。
/// Chrome AI取り込みとJSONファイル取り込みはラベル・説明文で区別する。
class TopicAddChoiceSheet extends StatelessWidget {
  const TopicAddChoiceSheet({super.key});

  static Future<TopicAddMethod?> show(BuildContext context) {
    final palette = AppColors.current;
    return showModalBottomSheet<TopicAddMethod>(
      context: context,
      backgroundColor: palette.cardFill,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const TopicAddChoiceSheet(),
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
                'お題を追加'.tr(lang),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: palette.textOnCardPrimary,
                ),
              ),
              const SizedBox(height: 4),
              _ChoiceRow(
                icon: Icons.auto_awesome,
                label: 'AIで追加'.tr(lang),
                subtitle: 'お題_追加_説明_AI'.tr(lang),
                onTap: () => Navigator.of(context).pop(TopicAddMethod.ai),
              ),
              _ChoiceRow(
                icon: Icons.edit_note_rounded,
                label: '自分で追加'.tr(lang),
                subtitle: 'お題_追加_説明_手入力'.tr(lang),
                onTap: () => Navigator.of(context).pop(TopicAddMethod.manual),
              ),
              _ChoiceRow(
                icon: Icons.download_outlined,
                label: 'ファイルをインポート'.tr(lang),
                subtitle: 'お題_追加_説明_ファイルインポート'.tr(lang),
                onTap: () =>
                    Navigator.of(context).pop(TopicAddMethod.jsonImport),
              ),
              _ChoiceRow(
                icon: Icons.upload_outlined,
                label: 'エクスポート'.tr(lang),
                subtitle: 'お題_追加_説明_エクスポート'.tr(lang),
                onTap: () =>
                    Navigator.of(context).pop(TopicAddMethod.jsonExport),
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
