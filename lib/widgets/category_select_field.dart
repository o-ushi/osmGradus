import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../main.dart' show appSettings;
import '../models/topic_category.dart';
import '../theme/app_colors.dart';
import '../views/topics/category_select_sheet.dart';

/// タップでカテゴリ一覧シート（`CategorySelectSheet`）を開く、
/// osmWashabeのカテゴリPickerに相当するトリガー行。
class CategorySelectField extends StatelessWidget {
  const CategorySelectField({
    super.key,
    required this.selected,
    required this.onChanged,
    this.availableCategories = TopicCategory.values,
    this.onCardBackground = false,
  });

  final TopicCategory selected;
  final ValueChanged<TopicCategory> onChanged;

  /// 一覧シートに表示する選択肢。既定は全カテゴリ。
  final List<TopicCategory> availableCategories;

  /// trueのとき[AiImportCard]など[cardFill]上に載せる想定で、
  /// 文字色を[AppPalette.textOnCardPrimary]に切り替える。
  final bool onCardBackground;

  Future<void> _openSheet(BuildContext context) async {
    final picked = await CategorySelectSheet.show(
      context,
      selected: selected,
      categories: availableCategories,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    final textColor = onCardBackground
        ? palette.textOnCardPrimary
        : palette.textOnScenePrimary;
    return GestureDetector(
      onTap: () => _openSheet(context),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(
              'カテゴリ'.tr(lang),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                selected.labelKey().tr(lang),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              color: textColor,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
