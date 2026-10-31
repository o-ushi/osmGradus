import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../main.dart' show appSettings;
import '../theme/app_colors.dart';

/// スタートアップ・使い方画面の「次回から表示しない」チェック。
class DontShowAgainCheckbox extends StatelessWidget {
  const DontShowAgainCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                side: BorderSide(color: palette.textOnScenePrimary, width: 1.5),
                fillColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? palette.accentColor
                      : Colors.transparent,
                ),
                checkColor: palette.onAccent,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                '次回から表示しない'.tr(appSettings.language),
                style: TextStyle(
                  fontSize: 15,
                  color: palette.textOnScenePrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// スタートアップ・使い方画面の下部に固定する「次回から表示しない」と確定ボタン
/// （osmNichinichiの`StartupBottomBar`の移植）。両画面で位置がぴったり揃うよう、
/// 余白もここで決める。
class StartupBottomBar extends StatelessWidget {
  const StartupBottomBar({
    super.key,
    required this.dontShowAgain,
    required this.onDontShowAgainChanged,
    required this.label,
    required this.onPressed,
  });

  final bool dontShowAgain;
  final ValueChanged<bool> onDontShowAgainChanged;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    // 短い画面（iPadのiPhone互換ウィンドウなど）では上下を詰める。
    final short = MediaQuery.sizeOf(context).height <= 700;
    return Padding(
      padding: EdgeInsets.fromLTRB(32, short ? 4 : 8, 32, short ? 12 : 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DontShowAgainCheckbox(
            value: dontShowAgain,
            onChanged: onDontShowAgainChanged,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: palette.accentColor,
                foregroundColor: palette.onAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
