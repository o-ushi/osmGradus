import 'package:flutter/material.dart';

import '../models/pronunciation_exercise.dart';
import '../theme/app_colors.dart';

/// レイヤーⅤ：10問読み上げセッションの1問分を表示するカード。
/// 問題番号・対象カテゴリ・日本語短文・かな読み・ベトナム語ヒントを表示する
/// （録音操作自体はこのカードの外側で行う）。
class PronunciationExerciseCard extends StatelessWidget {
  const PronunciationExerciseCard({
    super.key,
    required this.exercise,
    required this.questionNumber,
    required this.totalQuestions,
  });

  final PronunciationExercise exercise;

  /// 1始まりの現在の問題番号。
  final int questionNumber;
  final int totalQuestions;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$questionNumber / $totalQuestions',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: palette.textOnCardSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: palette.cardAccent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  exercise.category.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: palette.textOnCardPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            exercise.sentence,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.5,
              color: palette.textOnCardPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            exercise.reading,
            style: TextStyle(fontSize: 15, color: palette.textOnCardSecondary),
          ),
          const SizedBox(height: 12),
          Text(
            exercise.vietnameseHint,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: palette.textOnCardSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
