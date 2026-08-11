import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../topics/question_prompt_list_screen.dart';
import 'layer2_question_prompt_detail_screen.dart';

/// レイヤーⅡ「問題文一覧から選ぶ」モード（Step 3）。[QuestionPromptListScreen]を
/// 一覧として使い、行タップで[Layer2QuestionPromptDetailScreen]をpushする。
///
/// レイヤーⅠの「II」から来たときの「トップ・一覧をスキップして直接詳細を
/// 開く」処理は、このウィジェット自身の[initState]（一度しか呼ばれず、既に
/// マウント済みのときは反応しない）では信頼できないため、ここでは持たない。
/// 代わりに[Layer2EntryScreenState.openPromptDetail]が、このウィジェットの
/// 生成有無に関係なく毎回確実に[Layer2QuestionPromptDetailScreen]を
/// 直接pushする（[reload]は一覧を最新化するためにその後で呼ぶ）。
class Layer2QuestionPromptScreen extends StatefulWidget {
  const Layer2QuestionPromptScreen({
    super.key,
    this.onOpenPromptDetail,
    this.onSelectLayer,
    this.onGoToStart,
  });

  /// 詳細画面の「III」から[MainShellState.openPromptDetailInLayer]へ転送する。
  final void Function(int layerIndex, String promptId)? onOpenPromptDetail;

  /// 詳細画面の常設[AppHeader]から[MainShellState.selectLayer]相当へ転送する。
  final ValueChanged<int>? onSelectLayer;

  /// 詳細画面の常設[AppHeader]の長押しから、スタート画面へ転送する。
  final VoidCallback? onGoToStart;

  @override
  State<Layer2QuestionPromptScreen> createState() =>
      Layer2QuestionPromptScreenState();
}

class Layer2QuestionPromptScreenState
    extends State<Layer2QuestionPromptScreen> {
  final _listKey = GlobalKey<QuestionPromptListScreenState>();

  /// [Layer2EntryScreenState.openPromptDetail]がpushしたスキップ遷移から
  /// 戻ってきたあと、一覧を読み直すために呼ぶ。
  Future<void> reload() async {
    await _listKey.currentState?.reload();
  }

  Future<void> _openDetail(
    BuildContext context,
    String promptId, {
    required List<String> promptIds,
    required int initialIndex,
  }) async {
    await Layer2QuestionPromptDetailScreen.push(
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
      progressLabel: '要約',
      doneAxisLabel: '要約記入状況',
      isDone: (prompt) => prompt.summary.isNotEmpty,
      onTap: (context, prompt, orderedPrompts) => _openDetail(
        context,
        prompt.id,
        promptIds: orderedPrompts.map((p) => p.id).toList(),
        initialIndex: orderedPrompts.indexWhere((p) => p.id == prompt.id),
      ),
      trailingBuilder: (prompt) => Text(
        prompt.hitScore?.toString() ?? 'ー',
        style: TextStyle(fontSize: 13, color: palette.textOnSceneSecondary),
      ),
    );
  }
}
