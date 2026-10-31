import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../models/question_prompt_draw_selection.dart';
import '../models/topic_category.dart';
import '../theme/app_colors.dart';
import 'ai_import_shared.dart';
import 'question_prompt_draw_select_field.dart';
import 'question_prompt_icon_action_button.dart';

/// 問題文の追加・編集で共通のフォーム（カテゴリ・本文・条件・タブ・アクション）。
class QuestionPromptEditorForm extends StatelessWidget {
  const QuestionPromptEditorForm({
    super.key,
    required this.lang,
    required this.drawSelection,
    required this.onDrawSelectionChanged,
    required this.showRandomInCategory,
    required this.bodyController,
    required this.conditionController,
    required this.category,
    required this.tabKeys,
    required this.selectedTags,
    required this.onToggleTag,
    required this.onAddCustomTag,
    required this.submitIcon,
    required this.submitTooltipKey,
    required this.onSubmit,
    required this.canSubmit,
    this.isSubmitting = false,
    this.bodyHintKey,
    this.footer,
    this.statusMessage,
    this.statusIsError = false,
  });

  final String lang;
  final QuestionPromptDrawSelection drawSelection;
  final ValueChanged<QuestionPromptDrawSelection> onDrawSelectionChanged;
  final bool showRandomInCategory;
  final TextEditingController bodyController;
  final TextEditingController conditionController;
  final TopicCategory category;
  final List<String> tabKeys;
  final Set<String> selectedTags;
  final ValueChanged<String> onToggleTag;
  final VoidCallback onAddCustomTag;
  final IconData submitIcon;
  final String submitTooltipKey;
  final VoidCallback? onSubmit;
  final bool canSubmit;
  final bool isSubmitting;
  final String? bodyHintKey;
  final Widget? footer;
  final String? statusMessage;
  final bool statusIsError;

  bool get _isSituational => category == TopicCategory.situational;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return AiImportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuestionPromptDrawSelectField(
            selected: drawSelection,
            showSituational: true,
            showRandom: showRandomInCategory,
            onChanged: onDrawSelectionChanged,
            onCardBackground: true,
          ),
          const SizedBox(height: 12),
          Text(
            (_isSituational ? '状況' : '本文').tr(lang),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: palette.textOnCardSecondary,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: bodyController,
            minLines: _isSituational ? 2 : 3,
            maxLines: _isSituational ? 6 : 8,
            style: TextStyle(color: palette.textOnCardPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: bodyHintKey?.tr(lang),
              hintStyle: TextStyle(color: palette.textOnCardSecondary),
              filled: true,
              fillColor: palette.subpageBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (_isSituational) ...[
            const SizedBox(height: 12),
            Text(
              '条件'.tr(lang),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: palette.textOnCardSecondary,
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: conditionController,
              minLines: 2,
              maxLines: 6,
              style: TextStyle(color: palette.textOnCardPrimary, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: palette.subpageBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
          if (!_isSituational) ...[
            const SizedBox(height: 16),
            Text(
              'タブ'.tr(lang),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: palette.textOnCardPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tabKey in tabKeys)
                  _QuestionPromptTagSelectChip(
                    label: tabKey.tr(lang),
                    selected: selectedTags.contains(tabKey),
                    onTap: () => onToggleTag(tabKey),
                  ),
                _QuestionPromptTagAddChip(
                  tooltipKey: '新しいタブ',
                  lang: lang,
                  onTap: onAddCustomTag,
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          QuestionPromptIconActionButton(
            icon: submitIcon,
            tooltipKey: submitTooltipKey,
            lang: lang,
            onPressed: canSubmit ? onSubmit : null,
            loading: isSubmitting,
          ),
          if (statusMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              statusMessage!.tr(lang),
              style: TextStyle(
                fontSize: 12,
                color: statusIsError ? Colors.orange : Colors.green,
              ),
            ),
          ],
          if (footer != null) ...[
            const SizedBox(height: 16),
            Divider(color: palette.cardBorder),
            const SizedBox(height: 8),
            footer!,
          ],
        ],
      ),
    );
  }
}

/// 問題文編集フォーム内のタブ選択チップ。
class _QuestionPromptTagSelectChip extends StatelessWidget {
  const _QuestionPromptTagSelectChip({
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
    final fill = selected
        ? palette.accentColor.withValues(alpha: 0.18)
        : palette.subpageBackground;
    final border = selected ? palette.accentColor : palette.cardBorder;
    final foreground = selected
        ? palette.accentColor
        : palette.textOnCardPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(Icons.check_rounded, size: 16, color: foreground),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 「＋」だけの独自タブ追加チップ。
class _QuestionPromptTagAddChip extends StatelessWidget {
  const _QuestionPromptTagAddChip({
    required this.tooltipKey,
    required this.lang,
    required this.onTap,
  });

  final String tooltipKey;
  final String lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return Tooltip(
      message: tooltipKey.tr(lang),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Ink(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.subpageBackground,
              border: Border.all(color: palette.cardBorder),
            ),
            child: Icon(
              Icons.add_rounded,
              size: 20,
              color: palette.textOnCardPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// 追加・編集画面共通のヘッダー（タイトル＋閉じる）。
class QuestionPromptEditorHeader extends StatelessWidget {
  const QuestionPromptEditorHeader({
    super.key,
    required this.titleKey,
    required this.lang,
  });

  final String titleKey;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              titleKey.tr(lang),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: palette.textOnScenePrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close, color: palette.textOnScenePrimary),
            tooltip: 'キャンセル'.tr(lang),
          ),
        ],
      ),
    );
  }
}
