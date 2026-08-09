import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 起動画面のレイヤー選択リストで使う、アイコン中心・文字少なめのタイル。
/// 各レイヤーごとに枠を分けず、1つの帯にまとめて並べる前提のため、
/// 背景は持たず（シーンの背景がそのまま透けて見える）、文字色もシーン用の
/// 白系（[AppPalette.textOnScenePrimary]/[textOnSceneSecondary]）を使う。
class LayerListTile extends StatelessWidget {
  const LayerListTile({
    super.key,
    required this.numeral,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.onLongPress,
  });

  final String numeral;
  final String title;
  final String subtitle;
  final Color color;

  /// タップ：進行中の状態があれば続きから再開する。
  final VoidCallback onTap;

  /// 長押し：進行中の状態を破棄して最初から始める（非nullなら有効）。
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Text(
                numeral,
                style: TextStyle(
                  color: palette.onFill(color),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: palette.textOnScenePrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: palette.textOnSceneSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
