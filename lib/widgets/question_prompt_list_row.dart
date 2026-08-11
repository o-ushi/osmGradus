import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 問題文一覧の1行。左に実施状況アイコン（☑️/🔲）、本文は1行省略で表示する。
/// [trailing]を渡すと、実施状況アイコンの直前に的中度・PREPスコア等の
/// 列（レイヤーⅡ以降の一覧、Step 3〜6）を追加できる。
class QuestionPromptListRow extends StatelessWidget {
  const QuestionPromptListRow({
    super.key,
    required this.done,
    required this.body,
    required this.onTap,
    this.trailing,
  });

  final bool done;
  final String body;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(
              done ? Icons.check_box : Icons.check_box_outline_blank,
              color: done ? palette.accentColor : palette.textOnSceneSecondary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  color: palette.textOnScenePrimary,
                ),
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}
