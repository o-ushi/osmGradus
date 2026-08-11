import 'package:flutter/material.dart';

import '../models/question_prompt.dart';
import '../models/question_prompt_summary_header_scores.dart';
import '../theme/app_colors.dart';
import 'layer_numeral_badge.dart';

/// 総評画面上部のⅠ〜Ⅴアイコン＋点数（Step 9）。
///
/// 起動画面と同じ色付き丸＋ローマ数字（[LayerNumeralIcon]）。点数は
/// [QuestionPromptSummaryHeaderScores]。本文の詳細欄とは役割を分け、
/// ここは換算後の短いラベルだけを並べる。
class QuestionPromptSummaryScoreHeader extends StatelessWidget {
  const QuestionPromptSummaryScoreHeader({super.key, required this.prompt});

  final QuestionPrompt prompt;

  static Key scoreKey(int layerIndex) =>
      Key('summary-header-score-$layerIndex');

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final labels = QuestionPromptSummaryHeaderScores.labels(prompt);

    return Row(
      children: [
        for (var i = 0; i < 5; i++)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LayerNumeralIcon(layerIndex: i, size: 28),
                const SizedBox(height: 6),
                Text(
                  labels[i],
                  key: scoreKey(i),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                    color: palette.textOnScenePrimary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
