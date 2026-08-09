import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/saved_vocabulary_check.dart';
import '../../services/vocabulary_check_storage.dart';
import '../../theme/app_colors.dart';
import '../../widgets/history_format_badge.dart';
import '../../widgets/history_list_card.dart';
import '../../widgets/history_list_scaffold.dart';
import 'vocabulary_check_detail_screen.dart';

/// レイヤーⅠ単語テストの結果一覧（[PronunciationHistoryScreen]と同じ、
/// 左スワイプ＋確認ダイアログでの削除パターンを流用する）。
class VocabularyCheckHistoryScreen extends StatelessWidget {
  const VocabularyCheckHistoryScreen({super.key});

  static Future<void> push(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const VocabularyCheckHistoryScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final storage = VocabularyCheckStorage();
    return HistoryListScaffold<SavedVocabularyCheck>(
      title: '語彙力評価結果',
      emptyMessage: 'まだ語彙力評価結果がありません',
      languageCode: lang,
      loadAll: storage.loadAll,
      delete: (item) => storage.delete(item.id),
      itemId: (item) => item.id,
      onItemTap: (context, saved) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VocabularyCheckDetailScreen(check: saved),
        ),
      ),
      buildItem: (context, saved, palette, lang) => HistoryListCard(
        createdAt: saved.createdAt,
        languageCode: lang,
        badges: [
          if (saved.evaluation == null)
            HistoryFormatBadge(label: '未解析'.tr(lang)),
        ],
        children: _buildCardBody(palette, lang, saved),
      ),
    );
  }

  /// 評価が解析済みなら★表示と正解数、未解析ならAI回答原文（またはその
  /// プレビュー）を表示する（[PronunciationHistoryScreen]と同じ考え方）。
  static List<Widget> _buildCardBody(
    AppPalette palette,
    String lang,
    SavedVocabularyCheck saved,
  ) {
    final evaluation = saved.evaluation;
    if (evaluation == null) {
      final text = saved.unparsedResponse ?? '';
      return [
        Text(
          text.isEmpty ? '（発話が認識できませんでした）'.tr(lang) : text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 15, color: palette.textOnCardPrimary),
        ),
      ];
    }

    return [
      Text(evaluation.starDisplay, style: const TextStyle(fontSize: 18)),
      const SizedBox(height: 4),
      Text(
        'レイヤーⅠ_語彙_正解数'.trFmt(lang, [
          '${evaluation.correctCount}',
          '${saved.questions.length}',
        ]),
        style: TextStyle(fontSize: 13, color: palette.textOnCardSecondary),
      ),
    ];
  }
}
