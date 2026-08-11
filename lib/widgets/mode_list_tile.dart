import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// レイヤー入口の3択・2択画面で使う、見出し文字（例：「語彙を増やす」）。
/// [Layer1EntryScreen]・[Layer2EntryScreen]など、複数のレイヤー入口で共有する。
class ModeSectionHeading extends StatelessWidget {
  const ModeSectionHeading({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: palette.textOnSceneSecondary,
        ),
      ),
    );
  }
}

/// アイコン＋ラベルを横並びにした、縦積みの選択行。
/// [Layer1EntryScreen]・[Layer2EntryScreen]など、複数のレイヤー入口で共有する。
class ModeListTile extends StatelessWidget {
  const ModeListTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.caption,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// falseの間はタップに反応せず、アイコン・ラベルを薄く表示する
  /// （レイヤーⅤ「長文読み上げ」で保存済みの長文が無いときなど）。
  final bool enabled;

  /// [enabled]がfalseのときだけ、ラベルの下に小さく表示する案内文。
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final color = enabled
        ? palette.textOnScenePrimary
        : palette.textOnScenePrimary.withValues(alpha: 0.35);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 56, color: color),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            if (!enabled && caption != null)
              Padding(
                padding: const EdgeInsets.only(left: 76, top: 4),
                child: Text(
                  caption!,
                  style: TextStyle(
                    fontSize: 12,
                    color: palette.textOnSceneSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
