import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../models/pronunciation_evaluation.dart';
import '../models/pronunciation_exercise.dart';
import '../services/pronunciation_advice_service.dart';
import '../theme/app_colors.dart';

/// レイヤーⅤ：Chrome AIの5カテゴリ参考評価（[PronunciationEvaluation]）を表示する。
///
/// 貼り付け直後の保存前プレビュー（[Layer5ScreenState]）で使う。
/// 録音音声そのものはChrome AIへ送っておらず、期待文と端末STT結果の
/// 文字列比較に基づく評価であるため、その旨を明示する。
class PronunciationEvaluationResultView extends StatelessWidget {
  const PronunciationEvaluationResultView({
    super.key,
    required this.evaluation,
    required this.languageCode,
  });

  final PronunciationEvaluation evaluation;
  final String languageCode;

  static const _adviceService = PronunciationAdviceService();

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final lang = languageCode;
    final summary = evaluation.displaySummary(lang);
    final advice = _adviceService.buildAdvice(evaluation, lang);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: palette.cardAccent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'STT結果に基づく参考評価です（音声そのものは判定していません）。'.tr(lang),
            style: TextStyle(fontSize: 12, color: palette.textOnCardSecondary),
          ),
        ),
        const SizedBox(height: 12),
        for (final category in PronunciationCategory.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _CategoryRow(
              category: category,
              categoryEvaluation: evaluation.categoryEvaluations[category],
            ),
          ),
        if (summary.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            summary,
            style: TextStyle(fontSize: 14, color: palette.textOnCardPrimary),
          ),
          const SizedBox(height: 12),
        ],
        if (advice.isNotEmpty)
          Text(
            advice,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: palette.textOnCardPrimary,
            ),
          ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category, required this.categoryEvaluation});

  final PronunciationCategory category;
  final PronunciationCategoryEvaluation? categoryEvaluation;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final evaluation = categoryEvaluation;
    final singleFeedback = evaluation?.feedback?.trim();
    final hasSingleFeedback =
        singleFeedback != null && singleFeedback.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          category.label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: palette.textOnCardPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          evaluation?.starDisplay ?? '☆☆☆☆☆',
          style: TextStyle(fontSize: 16, color: palette.textOnCardPrimary),
        ),
        if (evaluation != null) ...[
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasSingleFeedback)
                  // 新形式（evaluationVersion v2以降）：評価取得時のアプリ表示
                  // 言語で書かれたフィードバックを1つだけ表示する。
                  Text(
                    singleFeedback,
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.textOnCardSecondary,
                    ),
                  )
                else ...[
                  // 旧形式（v1）互換：日本語・ベトナム語の両方が保存されて
                  // いるため、これまで通り両方併記する。
                  if (evaluation.feedbackJa != null)
                    Text(
                      evaluation.feedbackJa!,
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.textOnCardSecondary,
                      ),
                    ),
                  if (evaluation.feedbackVi != null)
                    Text(
                      evaluation.feedbackVi!,
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.textOnCardSecondary,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
