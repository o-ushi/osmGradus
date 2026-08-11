import 'package:flutter/material.dart';

import '../../models/question_prompt.dart';
import '../topics/question_prompt_list_screen.dart';
import 'layer1_question_prompt_detail_screen.dart';

/// レイヤーⅠ「問題文解析」モード（Step 2）。[QuestionPromptListScreen]を
/// そのまま一覧として使い、行タップで[Layer1QuestionPromptDetailScreen]を
/// pushする（詳細から戻ったら一覧を読み直す。取り込みで増えているため）。
class Layer1QuestionPromptScreen extends StatefulWidget {
  const Layer1QuestionPromptScreen({
    super.key,
    this.onOpenPromptDetail,
    this.onSelectLayer,
    this.onGoToStart,
  });

  /// 詳細画面の「II」から[MainShellState.openPromptDetailInLayer]へ転送する。
  final void Function(int layerIndex, String promptId)? onOpenPromptDetail;

  /// 詳細画面の常設[AppHeader]から[MainShellState.selectLayer]相当へ転送する。
  final ValueChanged<int>? onSelectLayer;

  /// 詳細画面の常設[AppHeader]の長押しから、スタート画面へ転送する。
  final VoidCallback? onGoToStart;

  @override
  State<Layer1QuestionPromptScreen> createState() =>
      Layer1QuestionPromptScreenState();
}

class Layer1QuestionPromptScreenState
    extends State<Layer1QuestionPromptScreen> {
  final _listKey = GlobalKey<QuestionPromptListScreenState>();

  /// [Layer1EntryScreenState.openPromptDetail]がpushしたスキップ遷移から
  /// 戻ってきたあと、一覧を読み直すために呼ぶ。
  Future<void> reload() async {
    await _listKey.currentState?.reload();
  }

  Future<void> _openDetail(
    BuildContext context,
    QuestionPrompt prompt,
    List<QuestionPrompt> orderedPrompts,
  ) async {
    await Layer1QuestionPromptDetailScreen.push(
      context,
      promptIds: orderedPrompts.map((p) => p.id).toList(),
      initialIndex: orderedPrompts.indexWhere((p) => p.id == prompt.id),
      onOpenPromptDetail: widget.onOpenPromptDetail,
      onSelectLayer: widget.onSelectLayer,
      onGoToStart: widget.onGoToStart,
    );
    await _listKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return QuestionPromptListScreen(
      key: _listKey,
      title: '問題文一覧',
      progressLabel: '語彙テスト',
      doneAxisLabel: '語彙テスト実施状況',
      isDone: (prompt) => prompt.isLayer1Done,
      onTap: _openDetail,
    );
  }
}
