import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/question_prompt_draw_selection.dart';
import '../../services/question_prompt_tab_registry.dart';
import '../../theme/app_colors.dart';
import '../../widgets/category_select_row.dart';

/// レイヤーⅣランダム等で使う、タブ＋ランダム＋シチュエーションの
/// フラットなカテゴリ選択シート。
///
/// ```
/// 趣味 / 健康 / 旅行 / 家族 / 環境 / 会社 / ランダム
/// ─────────────── （15+60秒モードのみ下に続く）
/// シチュエーション
/// ```
class QuestionPromptDrawSelectSheet extends StatelessWidget {
  const QuestionPromptDrawSelectSheet({
    super.key,
    required this.selected,
    required this.showSituational,
    this.showRandom = true,
  });

  final QuestionPromptDrawSelection selected;

  /// false のとき（45秒・60秒モード）はシチュエーション行と区切り線を出さない。
  final bool showSituational;

  /// false のとき「ランダム」行を出さない（編集画面など）。
  final bool showRandom;

  static Future<QuestionPromptDrawSelection?> show(
    BuildContext context, {
    required QuestionPromptDrawSelection selected,
    required bool showSituational,
    bool showRandom = true,
  }) {
    final palette = AppColors.current;
    return showModalBottomSheet<QuestionPromptDrawSelection>(
      context: context,
      backgroundColor: palette.cardFill,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => QuestionPromptDrawSelectSheet(
        selected: selected,
        showSituational: showSituational,
        showRandom: showRandom,
      ),
    );
  }

  bool _isSelected(QuestionPromptDrawSelection option) =>
      selected == option;

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: SingleChildScrollView(
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
              '問題文のカテゴリ'.tr(lang),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: palette.textOnCardPrimary,
              ),
            ),
            const SizedBox(height: 8),
            for (final tabKey in QuestionPromptTabRegistry.builtInTabKeys)
              CategorySelectRow(
                label: tabKey.tr(lang),
                selected: _isSelected(QuestionPromptDrawSelection.tag(tabKey)),
                onTap: () => Navigator.of(
                  context,
                ).pop(QuestionPromptDrawSelection.tag(tabKey)),
              ),
            if (showRandom)
              CategorySelectRow(
                label: 'ランダム'.tr(lang),
                selected: _isSelected(
                  const QuestionPromptDrawSelection.generalRandom(),
                ),
                onTap: () => Navigator.of(context).pop(
                  const QuestionPromptDrawSelection.generalRandom(),
                ),
              ),
            if (showSituational) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(
                  height: 1,
                  color: palette.cardBorder,
                ),
              ),
              CategorySelectRow(
                label: 'シチュエーション'.tr(lang),
                selected: _isSelected(
                  const QuestionPromptDrawSelection.situational(),
                ),
                onTap: () => Navigator.of(context).pop(
                  const QuestionPromptDrawSelection.situational(),
                ),
              ),
            ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
