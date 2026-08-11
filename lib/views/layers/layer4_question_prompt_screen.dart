import 'package:flutter/material.dart';

import '../../data/jsst_reference_samples.dart';
import '../../theme/app_colors.dart';
import '../topics/question_prompt_list_screen.dart';
import 'layer4_question_prompt_detail_screen.dart';

/// レイヤーⅣ「問題文一覧から選ぶ」モード（Step 5）。[QuestionPromptListScreen]を
/// 一覧として使い、行タップで[Layer4QuestionPromptDetailScreen]をpushする。
///
/// Ⅲ→Ⅳスキップ遷移の直接pushは[Layer4EntryScreenState.openPromptDetail]が
/// 担う（このウィジェットの生成有無に関係なく毎回確実に動かすため。
/// [Layer3QuestionPromptScreen]と同じ設計）。[reload]は一覧を最新化する
/// ために、スキップ遷移から戻ったあとに呼ぶ。
class Layer4QuestionPromptScreen extends StatefulWidget {
  const Layer4QuestionPromptScreen({
    super.key,
    this.onOpenPromptDetail,
    this.onSelectLayer,
    this.onGoToStart,
  });

  /// 詳細画面の「V」から[MainShellState.openPromptDetailInLayer]へ転送する。
  final void Function(int layerIndex, String promptId)? onOpenPromptDetail;

  /// 詳細画面の常設[AppHeader]から[MainShellState.selectLayer]相当へ転送する。
  final ValueChanged<int>? onSelectLayer;

  /// 詳細画面の常設[AppHeader]の長押しから、スタート画面へ転送する。
  final VoidCallback? onGoToStart;

  @override
  State<Layer4QuestionPromptScreen> createState() =>
      Layer4QuestionPromptScreenState();
}

class Layer4QuestionPromptScreenState
    extends State<Layer4QuestionPromptScreen> {
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
    await Layer4QuestionPromptDetailScreen.push(
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
      progressLabel: 'JSST評点',
      doneAxisLabel: 'JSST評点記入状況',
      isDone: (prompt) => prompt.jsstScore != null,
      onTap: (context, prompt, orderedPrompts) => _openDetail(
        context,
        prompt.id,
        promptIds: orderedPrompts.map((p) => p.id).toList(),
        initialIndex: orderedPrompts.indexWhere((p) => p.id == prompt.id),
      ),
      trailingBuilder: (prompt) => Text(
        prompt.jsstScore == null
            ? 'ー'
            : JsstReferenceSamples.levelLabel(prompt.jsstScore),
        style: TextStyle(fontSize: 13, color: palette.textOnSceneSecondary),
      ),
    );
  }
}
