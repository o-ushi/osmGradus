import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../topics/question_prompt_list_screen.dart';
import 'layer3_question_prompt_detail_screen.dart';

/// レイヤーⅢ「問題文一覧から選ぶ」モード（Step 4）。[QuestionPromptListScreen]を
/// 一覧として使い、行タップで[Layer3QuestionPromptDetailScreen]をpushする。
///
/// Ⅱ→Ⅲスキップ遷移の直接pushは[Layer3EntryScreenState.openPromptDetail]が
/// 担う（このウィジェットの生成有無に関係なく毎回確実に動かすため。
/// [Layer2QuestionPromptScreen]と同じ設計）。[reload]は一覧を最新化する
/// ために、スキップ遷移から戻ったあとに呼ぶ。
class Layer3QuestionPromptScreen extends StatefulWidget {
  const Layer3QuestionPromptScreen({
    super.key,
    this.onOpenPromptDetail,
    this.onSelectLayer,
    this.onGoToStart,
  });

  /// 詳細画面の「IV」から[MainShellState.openPromptDetailInLayer]へ転送する。
  final void Function(int layerIndex, String promptId)? onOpenPromptDetail;

  /// 詳細画面の常設[AppHeader]から[MainShellState.selectLayer]相当へ転送する。
  final ValueChanged<int>? onSelectLayer;

  /// 詳細画面の常設[AppHeader]の長押しから、スタート画面へ転送する。
  final VoidCallback? onGoToStart;

  @override
  State<Layer3QuestionPromptScreen> createState() =>
      Layer3QuestionPromptScreenState();
}

class Layer3QuestionPromptScreenState
    extends State<Layer3QuestionPromptScreen> {
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
    await Layer3QuestionPromptDetailScreen.push(
      context,
      promptIds: promptIds,
      initialIndex: initialIndex,
      onOpenPromptDetail: widget.onOpenPromptDetail,
      onSelectLayer: widget.onSelectLayer,
      onGoToStart: widget.onGoToStart,
    );
    await _listKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return QuestionPromptListScreen(
      key: _listKey,
      title: '問題文一覧',
      progressLabel: 'PREP',
      doneAxisLabel: 'PREP記入状況',
      isDone: (prompt) => prompt.isPrepFilled,
      onTap: (context, prompt, orderedPrompts) => _openDetail(
        context,
        prompt.id,
        promptIds: orderedPrompts.map((p) => p.id).toList(),
        initialIndex: orderedPrompts.indexWhere((p) => p.id == prompt.id),
      ),
      trailingBuilder: (prompt) => Text(
        prompt.prepScore?.toString() ?? 'ー',
        style: TextStyle(fontSize: 13, color: palette.textOnSceneSecondary),
      ),
    );
  }
}
