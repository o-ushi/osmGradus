import 'dart:async';

import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/question_prompt.dart';
import '../../services/question_prompt_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_header.dart';
import '../../widgets/dice_action_row.dart';
import '../../widgets/layer_help_sheet.dart';
import '../../widgets/layer_numeral_badge.dart';
import '../../widgets/prep_label_row.dart';
import '../../widgets/question_prompt_nav_row.dart';
import '../../widgets/swipe_to_close_wrapper.dart';
import '../../widgets/text_edit_sheet.dart';
import '../../widgets/transport_icon_button.dart';

/// レイヤーⅢ「問題文一覧から選ぶ」の詳細画面（Step 4）。
///
/// レイヤーⅠ・Ⅱと同じ「予約席」レイアウト（共通ルール1）。「結論」
/// 「理由」「例示」の3枠すべてをPREP（結論・理由・具体例）の記入欄に
/// 転用し、それぞれタップで[TextEditSheet]を開く（レイヤーⅠ「理解」・
/// レイヤーⅡ「要約」と同じ、アイコンのみ・余白ゼロ・記入済みは橙）。
/// 下段は左2つをダミーのまま隠し、右端だけレイヤーⅣへの遷移ボタンに転用する。
///
/// 一覧から開いたときの表示順（[promptIds]）を保持し、「分野」枠に置いた
/// ▲▼ボタン（[QuestionPromptNavRow]）で前後の問題文へ画面を閉じずに移動
/// できる（▲＝前、▼＝次。[Layer1QuestionPromptDetailScreen]と同じ設計）。
class Layer3QuestionPromptDetailScreen extends StatefulWidget {
  const Layer3QuestionPromptDetailScreen({
    super.key,
    required this.promptIds,
    required this.initialIndex,
    this.onOpenPromptDetail,
    this.onSelectLayer,
    this.onGoToStart,
  });

  final List<String> promptIds;
  final int initialIndex;

  /// 「IV」タップ時に呼ぶ（[MainShellState.openPromptDetailInLayer]への参照）。
  final void Function(int layerIndex, String promptId)? onOpenPromptDetail;

  /// 画面上端の常設[AppHeader]「Ⅰ」〜「Ⅴ」タップ時に呼ぶ
  /// （[MainShellState.selectLayer]相当への参照）。
  final ValueChanged<int>? onSelectLayer;

  /// 画面上端の常設[AppHeader]のいずれかのボタン長押し時に呼ぶ
  /// （スタート画面へジャンプする導線。この画面自身を閉じてから呼ぶ）。
  final VoidCallback? onGoToStart;

  static Future<void> push(
    BuildContext context, {
    required List<String> promptIds,
    required int initialIndex,
    void Function(int layerIndex, String promptId)? onOpenPromptDetail,
    ValueChanged<int>? onSelectLayer,
    VoidCallback? onGoToStart,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Layer3QuestionPromptDetailScreen(
          promptIds: promptIds,
          initialIndex: initialIndex,
          onOpenPromptDetail: onOpenPromptDetail,
          onSelectLayer: onSelectLayer,
          onGoToStart: onGoToStart,
        ),
      ),
    );
  }

  @override
  State<Layer3QuestionPromptDetailScreen> createState() =>
      _Layer3QuestionPromptDetailScreenState();
}

class _Layer3QuestionPromptDetailScreenState
    extends State<Layer3QuestionPromptDetailScreen> {
  late int _index = widget.initialIndex;

  bool get _canGoPrevious => _index > 0;
  bool get _canGoNext => _index < widget.promptIds.length - 1;

  void _goPrevious() {
    if (!_canGoPrevious) return;
    setState(() => _index -= 1);
  }

  void _goNext() {
    if (!_canGoNext) return;
    setState(() => _index += 1);
  }

  void _handleHeaderSelect(int index) {
    Navigator.of(context).pop();
    widget.onSelectLayer?.call(index);
  }

  void _handleHeaderLongPress() {
    Navigator.of(context).pop();
    widget.onGoToStart?.call();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return SwipeToCloseWrapper(
      child: Scaffold(
        backgroundColor: palette.scene,
        // 結論・理由・具体例の入力は[TextEditSheet]（showModalBottomSheet）が
        // 自前でキーボード分の余白を確保するため、この画面自体はキーボード
        // 用にリサイズする必要がない。既定のtrueのままだと、キーボードで
        // 縮んだ高さにこの画面の固定要素（サイコロ枠・PREP行・IV等）が
        // 収まりきらずRenderFlexオーバーフローになる（実機で確認・修正）。
        resizeToAvoidBottomInset: false,
        appBar: AppHeader(
          currentIndex: 2,
          onSelect: _handleHeaderSelect,
          onLongPress: _handleHeaderLongPress,
        ),
        body: _Layer3PromptDetailBody(
          key: ValueKey(widget.promptIds[_index]),
          promptId: widget.promptIds[_index],
          onOpenPromptDetail: widget.onOpenPromptDetail,
          canGoPrevious: _canGoPrevious,
          canGoNext: _canGoNext,
          onGoPrevious: _goPrevious,
          onGoNext: _goNext,
        ),
      ),
    );
  }
}

class _Layer3PromptDetailBody extends StatefulWidget {
  const _Layer3PromptDetailBody({
    super.key,
    required this.promptId,
    this.onOpenPromptDetail,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onGoPrevious,
    required this.onGoNext,
  });

  final String promptId;
  final void Function(int layerIndex, String promptId)? onOpenPromptDetail;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onGoPrevious;
  final VoidCallback onGoNext;

  @override
  State<_Layer3PromptDetailBody> createState() =>
      _Layer3PromptDetailBodyState();
}

class _Layer3PromptDetailBodyState extends State<_Layer3PromptDetailBody> {
  final _service = QuestionPromptService();

  QuestionPrompt? _prompt;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final prompt = await _service.loadById(widget.promptId);
    if (!mounted) return;
    setState(() => _prompt = prompt);
  }

  Future<void> _persist(QuestionPrompt updated) async {
    setState(() => _prompt = updated);
    await _service.update(updated);
  }

  Future<void> _editConclusion() => _editField(
    title: '結論',
    initialValue: _prompt?.conclusion ?? '',
    apply: (prompt, value) => prompt.copyWith(conclusion: value),
  );

  Future<void> _editReason() => _editField(
    title: '理由',
    initialValue: _prompt?.reason ?? '',
    apply: (prompt, value) => prompt.copyWith(reason: value),
  );

  Future<void> _editExample() => _editField(
    title: '例示',
    initialValue: _prompt?.example ?? '',
    apply: (prompt, value) => prompt.copyWith(example: value),
  );

  Future<void> _editField({
    required String title,
    required String initialValue,
    required QuestionPrompt Function(QuestionPrompt prompt, String value) apply,
  }) async {
    final prompt = _prompt;
    if (prompt == null) return;
    final lang = appSettings.language;
    final edited = await TextEditSheet.show(
      context,
      title: title.tr(lang),
      initialValue: initialValue,
    );
    if (edited == null || !mounted) return;
    unawaited(_persist(apply(prompt, edited)));
  }

  void _showUsageHelp() {
    final lang = appSettings.language;
    LayerHelpSheet.show(
      context,
      title: '操作方法'.tr(lang),
      lines: [
        LayerHelpLine(text: 'レイヤーⅢ_問題文_使い方_PREP'.tr(lang)),
        LayerHelpLine(text: 'レイヤーⅢ_問題文_使い方_IV'.tr(lang)),
      ],
    );
  }

  void _goToLayer4() {
    final prompt = _prompt;
    if (prompt == null) return;
    Navigator.of(context).pop();
    widget.onOpenPromptDetail?.call(3, prompt.id);
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    final prompt = _prompt;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: prompt == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DiceActionRow(
                    showAdd: true,
                    addIcon: Icons.add_rounded,
                    addTooltip: '操作方法',
                    // 既存の問題文のPREPを記入するモードのため、ここからの
                    // 新規追加は行わない（タップは無効。長押しの使い方
                    // シートのみ）。
                    onAddTap: () {},
                    onAddLongPress: _showUsageHelp,
                  ),
                  const SizedBox(height: 4),
                  // 分野は一覧のフィルタで絞り込めるため、詳細では表示せず、
                  // 同じ枠に前後の問題文へ移動する▲▼ボタンを置く。
                  QuestionPromptNavRow(
                    canGoPrevious: widget.canGoPrevious,
                    canGoNext: widget.canGoNext,
                    onPrevious: widget.onGoPrevious,
                    onNext: widget.onGoNext,
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: palette.cardFill,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: palette.cardBorder),
                        ),
                        child: Text(
                          _displayText(prompt),
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.9,
                            color: palette.textOnCardPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // このレイヤーでは抽選（サイコロ）を使わないため、枠だけ
                  // 他レイヤーと揃えて確保し隠す。
                  const Visibility(
                    visible: false,
                    maintainState: true,
                    maintainAnimation: true,
                    maintainSize: true,
                    child: SizedBox(width: 196, height: 98),
                  ),
                  const SizedBox(height: 12),
                  PrepLabelRow(
                    showConclusion: true,
                    conclusionIcon: Icons.flag_rounded,
                    conclusionTooltip: '結論',
                    conclusionActive: prompt.conclusion.isNotEmpty,
                    onConclusionTap: _editConclusion,
                    conclusionHintTapText: '結論',
                    showReason: true,
                    reasonIcon: Icons.question_mark_rounded,
                    reasonTooltip: '理由',
                    reasonShowBorder: false,
                    reasonHorizontalPadding: 0,
                    reasonActive: prompt.reason.isNotEmpty,
                    onReasonTap: _editReason,
                    reasonHintTapText: '理由',
                    showExample: true,
                    exampleIcon: Icons.lightbulb_rounded,
                    exampleTooltip: '例示',
                    exampleActive: prompt.example.isNotEmpty,
                    exampleActiveFill: Colors.transparent,
                    exampleActiveForeground: Colors.orange,
                    onExampleTap: _editExample,
                    exampleHintTapText: '例示',
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TransportIconButton(
                          icon: Icons.circle,
                          tooltip: '',
                          visible: false,
                          onTap: null,
                          borderless: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TransportIconButton(
                          icon: Icons.circle,
                          tooltip: '',
                          visible: false,
                          onTap: null,
                          borderless: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LayerNumeralBadge(
                          layerIndex: 3,
                          onTap: _goToLayer4,
                          tooltip: 'レイヤーⅣタイトル'.tr(lang),
                          hintTapText: 'レイヤーⅣタイトル'.tr(lang),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  String _displayText(QuestionPrompt prompt) {
    final condition = prompt.situationCondition;
    if (condition == null || condition.isEmpty) return prompt.body;
    return '${prompt.body}\n\n$condition';
  }
}
