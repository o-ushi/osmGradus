import 'package:flutter/material.dart';

import '../../main.dart' show appSettings;
import '../../models/saved_scoring_result.dart';
import '../../services/question_prompt_service.dart';
import '../../services/scoring_result_storage.dart';
import '../../widgets/history_list_scaffold.dart';
import '../../widgets/scoring_result_card.dart';
import 'scoring_result_screen.dart';

/// レイヤーⅣの採点結果一覧。osmGenkiの日記一覧（`DiaryListPage`）と同じ、
/// 左スワイプ＋確認ダイアログで1件ずつ削除できるリストとして移植する
/// （osmWashabeには結果を永続化する仕組み自体が無いため、この画面自体は
/// osmGradus独自の追加機能）。カードをタップすると採点結果の詳細
/// （[ScoringResultScreen]）を開く。
class ScoringHistoryScreen extends StatelessWidget {
  const ScoringHistoryScreen({super.key});

  static Future<void> push(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ScoringHistoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final storage = ScoringResultStorage();
    return HistoryListScaffold<SavedScoringResult>(
      title: '採点結果',
      emptyMessage: 'まだ採点結果がありません',
      languageCode: lang,
      loadAll: storage.loadAll,
      delete: (item) => _deleteAndResync(storage, item),
      itemId: (item) => item.id,
      onItemTap: (context, saved) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ScoringResultScreen(result: saved),
        ),
      ),
      buildItem: (context, saved, palette, lang) => ScoringResultCard(
        result: saved.result,
        createdAt: saved.createdAt,
        prepStars: saved.prepStars,
        hitStars: saved.hitStars,
      ),
    );
  }
}

/// [item]を削除したあと、[item.questionPromptId]が紐づく問題文があれば
/// jsstScore/hitScore/prepScoreを残りの結果から再計算する（問題文一覧の
/// 実施状況が、削除済みの結果のまま古くなって残るのを防ぐ）。
Future<void> _deleteAndResync(
  ScoringResultStorage storage,
  SavedScoringResult item,
) async {
  await storage.delete(item.id);
  final promptId = item.questionPromptId;
  if (promptId == null) return;
  final remaining = await storage.loadAll();
  await QuestionPromptService().resyncJsstScores(promptId, remaining);
}
