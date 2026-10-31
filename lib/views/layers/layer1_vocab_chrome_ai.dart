part of 'layer1_vocab_screen.dart';


/// 単語テストの結果（★表示・各問の正誤とフィードバック）を表示する簡易
/// ダイアログ。貼り付け直後のその場確認用（履歴一覧・詳細画面でも同じ結果を見られる）。
class _VocabResultDialog extends StatelessWidget {
  const _VocabResultDialog({
    required this.evaluation,
    required this.session,
    required this.lang,
    this.comprehensionQuiz,
  });

  final VocabularyEvaluation evaluation;
  final VocabTestSession? session;
  final String lang;
  final SavedComprehensionQuizResult? comprehensionQuiz;

  int get _quizOffset => comprehensionQuiz != null ? 1 : 0;

  VocabularyQuestionEvaluation? _vocabEvalAt(int wordIndex) {
    final evalIndex = wordIndex + _quizOffset;
    if (evalIndex >= evaluation.questionEvaluations.length) return null;
    return evaluation.questionEvaluations[evalIndex];
  }

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
                  '${questions.length + (comprehensionQuiz != null ? 1 : 0)}',
                ]),
                style: TextStyle(
                  fontSize: 13,
                  color: palette.textOnCardSecondary,
                ),
              ),
              if (comprehensionQuiz != null) ...[
                const SizedBox(height: 4),
                Text(
                  '長文読解_語彙_内訳'.trFmt(lang, [
                    '${evaluation.correctCount - (comprehensionQuiz!.isCorrect ? 1 : 0)}',
                    '${questions.length}',
                    comprehensionQuiz!.isCorrect ? '1' : '0',
                    '1',
                  ]),
                  style: TextStyle(
                    fontSize: 12,
                    color: palette.textOnCardSecondary,
                  ),
                ),
              ],
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
              if (comprehensionQuiz != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        comprehensionQuiz!.isCorrect
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        size: 18,
                        color: comprehensionQuiz!.isCorrect
                            ? Colors.green
                            : palette.textOnCardSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${'長文読解_1秒チェック_見出し'.tr(lang)}: ${comprehensionQuiz!.question}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: palette.textOnCardPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              for (var i = 0; i < questions.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _vocabEvalAt(i)?.correct == true
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        size: 18,
                        color: _vocabEvalAt(i)?.correct == true
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
                            if (_vocabEvalAt(i)?.feedback != null)
                              Text(
                                _vocabEvalAt(i)!.feedback!,
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
