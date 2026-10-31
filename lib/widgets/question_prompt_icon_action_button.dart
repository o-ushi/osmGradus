import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../theme/app_colors.dart';

/// 問題文の追加・保存など、カード内の主アクション用アイコンボタン。
class QuestionPromptIconActionButton extends StatelessWidget {
  const QuestionPromptIconActionButton({
    super.key,
    required this.icon,
    required this.tooltipKey,
    required this.lang,
    this.onPressed,
    this.loading = false,
  });

  final IconData icon;
  final String tooltipKey;
  final String lang;
  final VoidCallback? onPressed;
  final bool loading;

  static const _size = 52.0;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final enabled = onPressed != null && !loading;
    return Align(
      alignment: Alignment.centerRight,
      child: Tooltip(
        message: tooltipKey.tr(lang),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            customBorder: const CircleBorder(),
            child: Ink(
              width: _size,
              height: _size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: enabled
                    ? palette.accentColor
                    : palette.cardBorder.withValues(alpha: 0.55),
                boxShadow: enabled
                    ? [
                        BoxShadow(
                          color: palette.accentColor.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: loading
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: palette.onAccent,
                      ),
                    )
                  : Icon(
                      icon,
                      size: 26,
                      color: enabled
                          ? palette.onAccent
                          : palette.textOnCardSecondary,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
