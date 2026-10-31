import 'package:flutter/material.dart';

import '../main.dart' show appSettings;
import '../localization/app_strings.dart';
import '../theme/app_colors.dart';
import 'question_prompt_list_hints.dart';

/// 問題文一覧の1行。左に実施状況アイコン（☑️/🔲）、本文は1行省略で表示する。
/// [tags]が非空（[TopicCategory.general]の問題文のみ）のときは、本文の下に
/// 小さなタブチップを最大2つ＋「+N」表示する（`question-prompt-tabs.md` Step 3）。
/// ⬜︎と本文は同じ行タップ領域。タップ＝[onTap]（詳細へ）、長押し＝[onLongPress]（編集）。
/// [trailing]を渡すと、実施状況アイコンの直前に的中度・PREPスコア等の
/// 列（レイヤーⅡ以降の一覧、Step 3〜6）を追加できる。
class QuestionPromptListRow extends StatelessWidget {
  const QuestionPromptListRow({
    super.key,
    required this.done,
    required this.body,
    required this.onTap,
    this.tags = const [],
    this.onLongPress,
    this.trailing,
  });

  final bool done;
  final String body;
  final VoidCallback onTap;
  final List<String> tags;
  final VoidCallback? onLongPress;
  final Widget? trailing;

  static const _maxVisibleTags = 2;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              onLongPress: onLongPress,
              onDoubleTap: () => QuestionPromptListHints.showRow(context),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Icon(
                    done ? Icons.check_box : Icons.check_box_outline_blank,
                    color:
                        done ? palette.accentColor : palette.textOnSceneSecondary,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          body,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            color: palette.textOnScenePrimary,
                          ),
                        ),
                        if (tags.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          _TagChipsRow(tags: tags),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/// [tags]を最大[QuestionPromptListRow._maxVisibleTags]個のチップ＋
/// 残数バッジ（「+N」）で表示する。
class _TagChipsRow extends StatelessWidget {
  const _TagChipsRow({required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    final visible = tags.take(QuestionPromptListRow._maxVisibleTags).toList();
    final overflow = tags.length - visible.length;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final tag in visible)
          _TagChip(label: tag.tr(lang), palette: palette),
        if (overflow > 0)
          _TagChip(label: '+$overflow', palette: palette, muted: true),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.palette,
    this.muted = false,
  });

  final String label;
  final AppPalette palette;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: muted
            ? palette.textOnScenePrimary.withValues(alpha: 0.1)
            : palette.textOnScenePrimary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: palette.textOnScenePrimary.withValues(
            alpha: muted ? 0.18 : 0.28,
          ),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: muted
              ? palette.textOnSceneSecondary
              : palette.textOnScenePrimary,
        ),
      ),
    );
  }
}
