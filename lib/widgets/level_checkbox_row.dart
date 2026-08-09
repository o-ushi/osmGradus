import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// N1/N2/N3などのレベルをチェックボックスで複数選択するときの1行。
/// レイヤーⅠの単語テストのレベル選択シート・語彙のAI生成画面で共有する。
class LevelCheckboxRow extends StatelessWidget {
  const LevelCheckboxRow({
    super.key,
    required this.label,
    required this.checked,
    required this.onChanged,
  });

  final String label;
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return InkWell(
      onTap: () => onChanged(!checked),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: checked,
                onChanged: (value) => onChanged(value ?? false),
                side: BorderSide(color: palette.textOnCardPrimary, width: 1.5),
                fillColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return palette.accentColor;
                  }
                  return Colors.transparent;
                }),
                checkColor: palette.onAccent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: palette.textOnCardPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
