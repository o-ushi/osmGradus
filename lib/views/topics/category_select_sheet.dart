import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/topic_category.dart';
import '../../theme/app_colors.dart';

/// osmWashabeのカテゴリ選択（`.pickerStyle(.menu)`）に相当する一覧シート。
/// 「日常の身近な話題」「ビジネスシーン」「シチュエーション」「ランダム」を
/// タップで選択し、選択中の項目にチェックマークを付ける。
class CategorySelectSheet extends StatelessWidget {
  const CategorySelectSheet({
    super.key,
    required this.selected,
    this.categories = TopicCategory.values,
  });

  final TopicCategory selected;

  /// 一覧に表示する選択肢。既定は全カテゴリだが、レイヤーⅢの45/60秒モードなど
  /// 一部のカテゴリ（シチュエーション）を選べなくしたい場面で絞り込める。
  final List<TopicCategory> categories;

  static Future<TopicCategory?> show(
    BuildContext context, {
    required TopicCategory selected,
    List<TopicCategory> categories = TopicCategory.values,
  }) {
    final palette = AppColors.current;
    return showModalBottomSheet<TopicCategory>(
      context: context,
      backgroundColor: palette.cardFill,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          CategorySelectSheet(selected: selected, categories: categories),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    return SafeArea(
      top: false,
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
              'お題のカテゴリ'.tr(lang),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: palette.textOnCardPrimary,
              ),
            ),
            const SizedBox(height: 8),
            for (final category in categories)
              _CategoryRow(
                label: category.labelKey().tr(lang),
                selected: category == selected,
                onTap: () => Navigator.of(context).pop(category),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
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
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: palette.textOnCardPrimary,
                ),
              ),
            ),
            if (selected) Icon(Icons.check, color: palette.accentColor),
          ],
        ),
      ),
    );
  }
}
