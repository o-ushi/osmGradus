import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../main.dart' show appSettings;
import '../models/question_prompt_draw_selection.dart';
import '../theme/app_colors.dart';
import '../views/topics/question_prompt_draw_select_sheet.dart';

/// 問題文のカテゴリ／タブ選択シートを開くトリガー行。
/// レイヤーⅡ〜Ⅳランダム・手動追加・編集などで使う。
class QuestionPromptDrawSelectField extends StatelessWidget {
  const QuestionPromptDrawSelectField({
    super.key,
    required this.selected,
    required this.showSituational,
    required this.onChanged,
    this.showRandom = true,
    this.onCardBackground = false,
  });

  final QuestionPromptDrawSelection selected;
  final bool showSituational;
  final bool showRandom;
  final ValueChanged<QuestionPromptDrawSelection> onChanged;
  final bool onCardBackground;

  Future<void> _openSheet(BuildContext context) async {
    final picked = await QuestionPromptDrawSelectSheet.show(
      context,
      selected: selected,
      showSituational: showSituational,
      showRandom: showRandom,
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
                selected.labelKey.tr(lang),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down, color: textColor, size: 22),
          ],
        ),
      ),
    );
  }
}
