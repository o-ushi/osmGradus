part of 'layer1_vocab_screen.dart';


/// 単語テストの結果（★表示・各問の正誤とフィードバック）を表示する簡易
/// ダイアログ。貼り付け直後のその場確認用（履歴一覧・詳細画面でも同じ結果を見られる）。
class _VocabResultDialog extends StatelessWidget {
  const _VocabResultDialog({
    required this.evaluation,
    required this.session,
    required this.lang,
  });

  final VocabularyEvaluation evaluation;
  final VocabTestSession? session;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final questions = session?.questions ?? const <VocabTestQuestion>[];
    return AlertDialog(
      title: Text('語彙力評価結果'.tr(lang)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                evaluation.starDisplay,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(height: 4),
              Text(
                'レイヤーⅠ_語彙_正解数'.trFmt(lang, [
                  '${evaluation.correctCount}',
                  '${questions.length}',
                ]),
                style: TextStyle(
                  fontSize: 13,
                  color: palette.textOnCardSecondary,
                ),
              ),
              if (evaluation.summary != null) ...[
                const SizedBox(height: 8),
                Text(
                  evaluation.summary!,
                  style: TextStyle(
                    fontSize: 13,
                    color: palette.textOnCardPrimary,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              for (var i = 0; i < questions.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        i < evaluation.questionEvaluations.length &&
                                evaluation.questionEvaluations[i].correct
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        size: 18,
                        color:
                            i < evaluation.questionEvaluations.length &&
                                evaluation.questionEvaluations[i].correct
                            ? Colors.green
                            : palette.textOnCardSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              questions[i].entry.word,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: palette.textOnCardPrimary,
                              ),
                            ),
                            if (i < evaluation.questionEvaluations.length &&
                                evaluation.questionEvaluations[i].feedback !=
                                    null)
                              Text(
                                evaluation.questionEvaluations[i].feedback!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: palette.textOnCardSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('完了'.tr(lang)),
        ),
      ],
    );
  }
}
