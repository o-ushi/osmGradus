import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/saved_vocabulary_check.dart';
import '../../models/vocab_test_session.dart';
import '../../models/vocabulary_evaluation.dart';
import '../../theme/app_colors.dart';
import '../../widgets/history_detail_header.dart';
import '../../widgets/history_raw_response_card.dart';
import '../../widgets/osm_subpage_scaffold.dart';

/// 保存済み単語テスト結果（[SavedVocabularyCheck]）の詳細画面
/// （[PronunciationCheckDetailScreen]と同じ構成）。出題した単語・各STT結果・
/// Chrome AIの参考評価（★・各問の正誤とフィードバック・全体講評）・
/// AI回答原文を表示する。評価の解析に失敗した記録は「未解析」を明示した
/// うえでAI回答原文のみを表示する。
class VocabularyCheckDetailScreen extends StatelessWidget {
  const VocabularyCheckDetailScreen({super.key, required this.check});

  final SavedVocabularyCheck check;

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    return OsmSubpageScaffold(
      title: Text('語彙力評価結果'.tr(lang)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          HistoryDetailHeader(
            createdAt: check.createdAt,
            languageCode: lang,
            badgeLabels: [
              if (check.evaluation == null) '未解析'.tr(lang),
              if (check.questionPromptId != null) 'レイヤーⅠ_語彙_問題文の見直し'.tr(lang),
              if (check.longArticleId != null) '長文読解_語彙_履歴バッジ'.tr(lang),
            ],
          ),
          if (check.questionPromptId != null) ...[
            const SizedBox(height: 12),
            _QuestionPromptCard(
              body: check.questionPromptBody ?? '',
              lang: lang,
            ),
          ],
          if (check.longArticleId != null) ...[
            const SizedBox(height: 12),
            _LongArticleCard(
              title: check.longArticleTitle ?? '',
              lang: lang,
            ),
          ],
          if (check.comprehensionQuiz != null) ...[
            const SizedBox(height: 12),
            _ComprehensionQuizCard(
              quiz: check.comprehensionQuiz!,
              lang: lang,
            ),
          ],
          const SizedBox(height: 12),
          ..._buildBody(palette, lang),
        ],
      ),
    );
  }

  List<Widget> _buildBody(AppPalette palette, String lang) {
    final questions = check.questions;
    final evaluation = check.evaluation;
    final widgets = <Widget>[];

    if (questions.isNotEmpty) {
      widgets.addAll([
        Text(
          '出題した単語'.tr(lang),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: palette.textOnSubpagePrimary,
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < questions.length; i++)
          _QuestionResultTile(
            index: i + 1 + check.vocabEvaluationOffset,
            question: questions[i],
            questionEvaluation: check.vocabQuestionEvaluationAt(i),
            languageCode: lang,
          ),
        const SizedBox(height: 16),
      ]);
    }

    if (evaluation != null) {
      widgets.addAll([
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.cardFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.cardBorder, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                evaluation.starDisplay,
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(height: 4),
              Text(
                'レイヤーⅠ_語彙_正解数'.trFmt(lang, [
                  '${check.combinedCorrectCount}',
                  '${check.combinedQuestionCount}',
                ]),
                style: TextStyle(
                  fontSize: 13,
                  color: palette.textOnCardSecondary,
                ),
              ),
              if (check.comprehensionQuiz != null) ...[
                const SizedBox(height: 4),
                Text(
                  '長文読解_語彙_内訳'.trFmt(lang, [
                    '${check.vocabEvaluationOffset == 1 ? evaluation.correctCount - (check.comprehensionQuiz!.isCorrect ? 1 : 0) : evaluation.correctCount}',
                    '${questions.length}',
                    check.comprehensionQuiz!.isCorrect ? '1' : '0',
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
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'AI回答原文'.tr(lang),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: palette.textOnSubpagePrimary,
          ),
        ),
        const SizedBox(height: 8),
        HistoryRawResponseCard(text: evaluation.rawResponse),
      ]);
    } else {
      widgets.addAll([
        Text(
          'AIの回答をまだ解析できていない記録です。AI回答原文のみ保存されています。'.tr(lang),
          style: TextStyle(fontSize: 12, color: palette.textOnSubpageSecondary),
        ),
        const SizedBox(height: 12),
        HistoryRawResponseCard(text: check.unparsedResponse ?? ''),
      ]);
    }

    return widgets;
  }
}

/// 「分からなかった単語だけテスト」（総評画面）経由の記録で、出題元の
/// 問題文本文を表示する（[PronunciationCheckDetailScreen._questionPromptCard]
/// と同じ構成）。
class _QuestionPromptCard extends StatelessWidget {
  const _QuestionPromptCard({required this.body, required this.lang});

  final String body;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'レイヤーⅠ_語彙_問題文の見直し'.tr(lang),
            style: TextStyle(fontSize: 12, color: palette.textOnCardSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: palette.textOnCardPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 長文読解の1秒チェック結果。長文タイトルの下・出題単語の上に置く。
class _ComprehensionQuizCard extends StatelessWidget {
  const _ComprehensionQuizCard({required this.quiz, required this.lang});

  final SavedComprehensionQuizResult quiz;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final accent = quiz.isCorrect ? Colors.green : Colors.redAccent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '長文読解_1秒チェック_見出し'.tr(lang),
            style: TextStyle(fontSize: 12, color: palette.textOnCardSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            quiz.question,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: palette.textOnCardPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'A. ${quiz.optionA}',
            style: TextStyle(fontSize: 13, color: palette.textOnCardPrimary),
          ),
          Text(
            'B. ${quiz.optionB}',
            style: TextStyle(fontSize: 13, color: palette.textOnCardPrimary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                quiz.isCorrect
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                size: 18,
                color: accent,
              ),
              const SizedBox(width: 6),
              Text(
                (quiz.isCorrect
                        ? '長文読解_1秒チェック_正解'
                        : '長文読解_1秒チェック_不正解')
                    .tr(lang),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: palette.textOnCardPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '長文読解_語彙_選択'.trFmt(lang, [quiz.selectedOption]),
            style: TextStyle(fontSize: 13, color: palette.textOnCardSecondary),
          ),
          if (!quiz.isCorrect) ...[
            const SizedBox(height: 2),
            Text(
              '長文読解_1秒チェック_正解表示'.trFmt(lang, [quiz.correctOption]),
              style: TextStyle(
                fontSize: 13,
                color: palette.textOnCardSecondary,
              ),
            ),
          ],
          if (quiz.explanationFor(lang).isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              quiz.explanationFor(lang),
              style: TextStyle(
                fontSize: 13,
                color: palette.textOnCardSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// レイヤーⅠ「長文読解」の語彙テスト経由の記録で、出題元の長文タイトルを
/// 表示する（[_QuestionPromptCard]と同じ構成。長文は問題文と違い本文が長い
/// ため、全文ではなく保存時点のタイトルのみを複製している）。
class _LongArticleCard extends StatelessWidget {
  const _LongArticleCard({required this.title, required this.lang});

  final String title;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '長文読解_語彙_履歴バッジ'.tr(lang),
            style: TextStyle(fontSize: 12, color: palette.textOnCardSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: palette.textOnCardPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 出題1問分（単語・読み・訳・端末STT結果・正誤とフィードバック）の表示。
class _QuestionResultTile extends StatelessWidget {
  const _QuestionResultTile({
    required this.index,
    required this.question,
    required this.questionEvaluation,
    required this.languageCode,
  });

  final int index;
  final SavedVocabQuestionResult question;
  final VocabularyQuestionEvaluation? questionEvaluation;
  final String languageCode;

  String _sttDisplay(String lang) {
    final result = question.sttResult;
    if (result != null && result.trim().isNotEmpty) return result;
    return question.status == VocabTestQuestionStatus.waiting
        ? '（未回答）'.tr(lang)
        : '（発話が認識できませんでした）'.tr(lang);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final lang = languageCode;
    final evaluation = questionEvaluation;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.cardFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.cardBorder, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (evaluation != null) ...[
            Icon(
              evaluation.correct
                  ? Icons.check_circle_rounded
                  : Icons.cancel_rounded,
              size: 18,
              color: evaluation.correct
                  ? Colors.green
                  : palette.textOnCardSecondary,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$index. ${question.word}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: palette.textOnCardPrimary,
                  ),
                ),
                if (question.reading.isNotEmpty)
                  Text(
                    question.reading,
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.textOnCardSecondary,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  _sttDisplay(lang),
                  style: TextStyle(
                    fontSize: 13,
                    color: palette.textOnCardSecondary,
                  ),
                ),
                if (evaluation?.feedback != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    evaluation!.feedback!,
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
      ),
    );
  }
}
