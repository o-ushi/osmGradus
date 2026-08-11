import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../theme/app_colors.dart';
import '../topics/question_prompt_list_screen.dart';
import 'layer5_question_prompt_detail_screen.dart';

/// レイヤーⅤ「問題文一覧から選ぶ」モード（Step 6）。[QuestionPromptListScreen]を
/// 一覧として使い、行タップで[Layer5QuestionPromptDetailScreen]をpushする。
///
/// Ⅳ→Ⅴスキップ遷移の直接pushは[Layer5EntryScreenState.openPromptDetail]が
/// 担う（このウィジェットの生成有無に関係なく毎回確実に動かすため。
/// [Layer4QuestionPromptScreen]と同じ設計）。[reload]は一覧を最新化する
/// ために、スキップ遷移から戻ったあとに呼ぶ。
class Layer5QuestionPromptScreen extends StatefulWidget {
  const Layer5QuestionPromptScreen({
    super.key,
    this.onSelectLayer,
    this.onGoToStart,
    this.onGoToSummary,
  });

  /// 詳細画面の常設[AppHeader]から[MainShellState.selectLayer]相当へ転送する。
  final ValueChanged<int>? onSelectLayer;

  /// 詳細画面の常設[AppHeader]の長押しから、スタート画面へ転送する。
  final VoidCallback? onGoToStart;

  /// AI発音評価が届いた後の「総評」タップで、この問題文のIDを渡して呼ぶ。
  /// 未指定（null）の間はボタン自体を表示しない（[Layer5Screen.onGoToSummary]参照）。
  final void Function(String promptId)? onGoToSummary;

  @override
  State<Layer5QuestionPromptScreen> createState() =>
      Layer5QuestionPromptScreenState();
}

class Layer5QuestionPromptScreenState
    extends State<Layer5QuestionPromptScreen> {
  final _listKey = GlobalKey<QuestionPromptListScreenState>();

  Future<void> reload() async {
    await _listKey.currentState?.reload();
  }

  Future<void> _openDetail(
    BuildContext context,
    String promptId, {
    required List<String> promptIds,
    required int initialIndex,
  }) async {
    await Layer5QuestionPromptDetailScreen.push(
      context,
      promptIds: promptIds,
      initialIndex: initialIndex,
      onSelectLayer: widget.onSelectLayer,
      onGoToStart: widget.onGoToStart,
      onGoToSummary: widget.onGoToSummary,
    );
    await _listKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    return QuestionPromptListScreen(
      key: _listKey,
      title: '問題文一覧',
      progressLabel: '発音評点',
      doneAxisLabel: '発音評点記入状況',
      isDone: (prompt) => prompt.hasPronunciationScore,
      onTap: (context, prompt, orderedPrompts) => _openDetail(
        context,
        prompt.id,
        promptIds: orderedPrompts.map((p) => p.id).toList(),
        initialIndex: orderedPrompts.indexWhere((p) => p.id == prompt.id),
      ),
      trailingBuilder: (prompt) => Text(
        prompt.hasPronunciationScore ? '済み'.tr(lang) : 'ー',
        style: TextStyle(fontSize: 13, color: palette.textOnSceneSecondary),
      ),
    );
  }
}
