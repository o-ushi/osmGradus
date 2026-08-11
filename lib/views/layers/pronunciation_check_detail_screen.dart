import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/pronunciation_exercise.dart';
import '../../models/pronunciation_practice_session.dart';
import '../../models/saved_pronunciation_check.dart';
import '../../theme/app_colors.dart';
import '../../widgets/history_detail_header.dart';
import '../../widgets/history_raw_response_card.dart';
import '../../widgets/osm_subpage_scaffold.dart';
import '../../widgets/pronunciation_evaluation_result_view.dart';

/// 保存済み発音チェック結果（[SavedPronunciationCheck]）の詳細画面。
///
/// 新形式（10問セッション＋5カテゴリ参考評価）は出題した10問・各STT結果・
/// 5カテゴリの評価（日本語/ベトナム語フィードバック含む）・AI回答原文を表示する。
/// 旧形式（自由発話・自由記述の記録）は「旧形式」であることを明示した上で
/// 従来通り文字起こしテキストのみを表示する。
class PronunciationCheckDetailScreen extends StatelessWidget {
  const PronunciationCheckDetailScreen({super.key, required this.check});

  final SavedPronunciationCheck check;

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    return OsmSubpageScaffold(
      title: Text('発音チェック'.tr(lang)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          HistoryDetailHeader(
            createdAt: check.createdAt,
            languageCode: lang,
            badgeLabels: [
              if (check.isLegacyFormat) '旧形式'.tr(lang),
              if (!check.isLegacyFormat && check.evaluation == null)
                '未解析'.tr(lang),
              if (check.source == 'long') '長文音読'.tr(lang),
              if (check.source == 'questionPrompt') '問題文回答'.tr(lang),
            ],
          ),
          const SizedBox(height: 12),
          ..._buildBody(palette, lang),
        ],
      ),
    );
  }

  List<Widget> _buildBody(AppPalette palette, String lang) {
    if (check.isLegacyFormat) {
      return [
        Text(
          '旧形式のデータです（かつての自由発話・自由記述の記録です）。'.tr(lang),
          style: TextStyle(fontSize: 12, color: palette.textOnSubpageSecondary),
        ),
        const SizedBox(height: 12),
        _transcriptCard(palette, lang),
      ];
    }

    final questions = check.questions;
    final evaluation = check.evaluation;
    final widgets = <Widget>[];

    if (check.source == 'long') {
      widgets.addAll([
        Text(
          '音読した長文'.tr(lang),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: palette.textOnSubpagePrimary,
          ),
        ),
        const SizedBox(height: 8),
        _longReadingCard(palette, lang),
        const SizedBox(height: 16),
      ]);
    }

    if (check.source == 'questionPrompt') {
      widgets.addAll([
        Text(
          '回答した問題文'.tr(lang),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: palette.textOnSubpagePrimary,
          ),
        ),
        const SizedBox(height: 8),
        _questionPromptCard(palette, lang),
        const SizedBox(height: 16),
      ]);
    }

    if (questions != null && questions.isNotEmpty) {
      widgets.addAll([
        Text(
          '出題した10問'.tr(lang),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: palette.textOnSubpagePrimary,
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < questions.length; i++)
          _QuestionResultTile(
            index: i + 1,
            question: questions[i],
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
          child: PronunciationEvaluationResultView(
            evaluation: evaluation,
            languageCode: lang,
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
        HistoryRawResponseCard(text: _unparsedDisplayText(lang)),
      ]);
    }

    return widgets;
  }

  /// 新形式で解析に失敗した記録の表示テキスト。[unparsedResponse]（AI回答
  /// 原文）があればそれを優先し、なければ念のため[transcript]にフォールバック
  /// する（新形式ではtranscriptは常に空文字のはずだが、安全のため）。
  String _unparsedDisplayText(String lang) {
    final unparsed = check.unparsedResponse;
    if (unparsed != null && unparsed.isNotEmpty) return unparsed;
    return check.transcript.isEmpty
        ? '（発話が認識できませんでした）'.tr(lang)
        : check.transcript;
  }

  /// 音読した長文のタイトルと、端末STTで文字起こしした音読結果
  /// （[SavedPronunciationCheck.transcript]）を表示する（[check.source]が
  /// `'long'`のときのみ）。
  Widget _longReadingCard(AppPalette palette, String lang) {
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
            check.longArticleTitle ?? '',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: palette.textOnCardSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            check.transcript.isEmpty
                ? '（発話が認識できませんでした）'.tr(lang)
                : check.transcript,
            style: TextStyle(fontSize: 15, color: palette.textOnCardPrimary),
          ),
        ],
      ),
    );
  }

  /// 対象の問題文の本文と、端末STTで文字起こしした発話
  /// （[SavedPronunciationCheck.transcript]）を表示する（[check.source]が
  /// `'questionPrompt'`のときのみ）。
  Widget _questionPromptCard(AppPalette palette, String lang) {
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
            check.questionPromptBody ?? '',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: palette.textOnCardSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            check.transcript.isEmpty
                ? '（発話が認識できませんでした）'.tr(lang)
                : check.transcript,
            style: TextStyle(fontSize: 15, color: palette.textOnCardPrimary),
          ),
        ],
      ),
    );
  }

  Widget _transcriptCard(AppPalette palette, String lang) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder, width: 1),
      ),
      child: SelectableText(
        check.transcript.isEmpty
            ? '（発話が認識できませんでした）'.tr(lang)
            : check.transcript,
        style: TextStyle(fontSize: 15, color: palette.textOnCardPrimary),
      ),
    );
  }
}

/// 出題1問分（期待文＋端末STT結果）の表示。
class _QuestionResultTile extends StatelessWidget {
  const _QuestionResultTile({
    required this.index,
    required this.question,
    required this.languageCode,
  });

  final int index;
  final SavedPronunciationQuestionResult question;
  final String languageCode;

  String _sttDisplay(String lang) {
    final result = question.sttResult;
    if (result != null && result.trim().isNotEmpty) return result;
    return question.status == PronunciationQuestionStatus.waiting
        ? '（未回答）'.tr(lang)
        : '（発話が認識できませんでした）'.tr(lang);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final lang = languageCode;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.cardFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$index. ${question.category.label}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: palette.textOnCardSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            question.sentence,
            style: TextStyle(fontSize: 15, color: palette.textOnCardPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            _sttDisplay(lang),
            style: TextStyle(fontSize: 13, color: palette.textOnCardSecondary),
          ),
        ],
      ),
    );
  }
}
