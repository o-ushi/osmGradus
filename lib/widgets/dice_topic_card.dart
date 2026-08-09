import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../main.dart' show appSettings;
import '../models/drawn_topic.dart';
import '../theme/app_colors.dart';

/// osmWashabeの `scrollableTopicCard` に相当。引く前はプレースホルダー文言、
/// 引いた後はお題本文（シチュエーションの場合は条件も）を表示する。
/// シャッフルアニメーションは行わず、即座にテキストを差し替える（軽量設計）。
class DiceTopicCard extends StatelessWidget {
  const DiceTopicCard({super.key, required this.topic});

  final DrawnTopic? topic;

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 160),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.cardFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.cardBorder, width: 1),
      ),
      alignment: Alignment.centerLeft,
      child: topic == null
          ? Text(
              'ボタンを押してお題を引いてください'.tr(lang),
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: 15,
                color: palette.textOnCardSecondary,
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  topic!.text,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                    color: palette.textOnCardPrimary,
                  ),
                ),
                if (topic!.subtext != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    topic!.subtext!,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: 14,
                      color: palette.textOnCardSecondary,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
