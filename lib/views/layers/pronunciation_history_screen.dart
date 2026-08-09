import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/pronunciation_evaluation.dart';
import '../../models/pronunciation_exercise.dart';
import '../../models/saved_pronunciation_check.dart';
import '../../services/pronunciation_advice_service.dart';
import '../../services/pronunciation_check_storage.dart';
import '../../theme/app_colors.dart';
import '../../widgets/history_format_badge.dart';
import '../../widgets/history_list_card.dart';
import '../../widgets/history_list_scaffold.dart';
import 'pronunciation_check_detail_screen.dart';

/// 履歴一覧のカテゴリ星表示用の短い1文字グリフ（[PronunciationCategoryLabel.label]
/// は一覧の1行に収めるには長すぎるため、この画面専用の短縮表記を使う）。
const _shortCategoryGlyph = {
  PronunciationCategory.tsu: 'つ',
  PronunciationCategory.zRow: 'ざ',
  PronunciationCategory.rRow: 'ラ',
  PronunciationCategory.longVowel: '長',
  PronunciationCategory.sokuon: '促',
};

/// レイヤーⅤの発音チェック結果一覧。`ScoringHistoryScreen`（レイヤーⅣ）と
/// 同じ、osmGenkiの日記一覧を踏襲した左スワイプ＋確認ダイアログでの
/// 削除パターンを流用する。
class PronunciationHistoryScreen extends StatelessWidget {
  const PronunciationHistoryScreen({super.key});

  static Future<void> push(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PronunciationHistoryScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final storage = PronunciationCheckStorage();
    return HistoryListScaffold<SavedPronunciationCheck>(
      title: '発音チェック結果',
      emptyMessage: 'まだ発音チェック結果がありません',
      languageCode: lang,
      loadAll: storage.loadAll,
      delete: (item) => storage.delete(item.id),
      itemId: (item) => item.id,
      onItemTap: (context, saved) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PronunciationCheckDetailScreen(check: saved),
        ),
      ),
      buildItem: (context, saved, palette, lang) => HistoryListCard(
        createdAt: saved.createdAt,
        languageCode: lang,
        badges: [
          if (saved.isLegacyFormat)
            HistoryFormatBadge(label: '旧形式'.tr(lang))
          else if (saved.evaluation == null)
            HistoryFormatBadge(label: '未解析'.tr(lang)),
          if (saved.source == 'long')
            HistoryFormatBadge(label: '長文音読'.tr(lang)),
        ],
        children: _buildCardBody(palette, lang, saved),
      ),
    );
  }

  static const _adviceService = PronunciationAdviceService();

  /// 新形式（5カテゴリ評価あり）は総合的な改善対象と5カテゴリの星、
  /// それ以外（旧形式・未解析）は文字起こしプレビューを表示する。
  static List<Widget> _buildCardBody(
    AppPalette palette,
    String lang,
    SavedPronunciationCheck saved,
  ) {
    final evaluation = saved.evaluation;
    if (evaluation == null) {
      final text = saved.unparsedResponse ?? saved.transcript;
      return [
        Text(
          text.isEmpty ? '（発話が認識できませんでした）'.tr(lang) : text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 15, color: palette.textOnCardPrimary),
        ),
      ];
    }

    final focusCategories = _adviceService.lowestScoringCategories(
      evaluation,
      maxCategories: 1,
    );
    final focusLabel = focusCategories.isEmpty
        ? null
        : focusCategories.first.label;

    return [
      if (focusLabel != null)
        Text(
          '改善の重点：%@'.trFmt(lang, [focusLabel]),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: palette.textOnCardPrimary,
          ),
        ),
      if (focusLabel != null) const SizedBox(height: 6),
      _CategoryStarsSummary(evaluation: evaluation),
    ];
  }
}

/// 5カテゴリの星評価を1行に収めた要約表示（履歴一覧用）。
/// カテゴリ名は[_shortCategoryGlyph]の短縮表記を使う。
class _CategoryStarsSummary extends StatelessWidget {
  const _CategoryStarsSummary({required this.evaluation});

  final PronunciationEvaluation evaluation;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: [
        for (final category in PronunciationCategory.values)
          Text(
            '${_shortCategoryGlyph[category]}'
            '${evaluation.categoryEvaluations[category]?.starDisplay ?? '☆☆☆☆☆'}',
            style: TextStyle(fontSize: 12, color: palette.textOnCardSecondary),
          ),
      ],
    );
  }
}
