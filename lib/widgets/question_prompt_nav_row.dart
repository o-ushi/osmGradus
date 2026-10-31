import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../main.dart' show appSettings;
import '../theme/app_colors.dart';

/// 「問題文一覧から選ぶ」の詳細画面で、[QuestionPromptNavRow]が入る「分野」枠
/// をそのまま差し替えて使う、前後の問題文へ移動する▲▼ボタン行。
/// 一覧から開いた詳細では分野は一覧のフィルタで絞り込めるため表示せず、
/// 代わりにここへ前後移動を置く（[canGoPrevious]/[canGoNext]がfalseの
/// 方向のボタンは表示しない）。
class QuestionPromptNavRow extends StatelessWidget {
  const QuestionPromptNavRow({
    super.key,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    return SizedBox(
      height: 32,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (canGoPrevious)
            _NavArrowButton(
              icon: Icons.keyboard_arrow_up_rounded,
              tooltip: '前の問題文'.tr(lang),
              onTap: onPrevious,
            ),
          if (canGoNext)
            _NavArrowButton(
              icon: Icons.keyboard_arrow_down_rounded,
              tooltip: '次の問題文'.tr(lang),
              onTap: onNext,
            ),
        ],
      ),
    );
  }
}

class _NavArrowButton extends StatelessWidget {
  const _NavArrowButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 28, color: palette.textOnScenePrimary),
        ),
      ),
    );
  }
}
