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

/// レイヤーⅡ「問題文一覧から選ぶ」の詳細画面（Step 3）。
///
/// レイヤーⅠと同じ「予約席」レイアウト（共通ルール1）。「結論」枠は
/// 「要約」の記入欄に転用し、タップで[TextEditSheet]を開いて回答の要約を
/// 記入する（記入済みなら背景青）。下段は左2つをダミーのまま隠し、右端だけ
/// レイヤーⅢへの遷移ボタンに転用する。
///
/// 一覧から開いたときの表示順（[promptIds]）を保持し、「分野」枠に置いた
/// ▲▼ボタン（[QuestionPromptNavRow]）で前後の問題文へ画面を閉じずに移動
/// できる（▲＝前、▼＝次。[Layer1QuestionPromptDetailScreen]と同じ設計）。
class Layer2QuestionPromptDetailScreen extends StatefulWidget {
  const Layer2QuestionPromptDetailScreen({
    super.key,
    required this.promptIds,
    required this.initialIndex,
    this.onOpenPromptDetail,
    this.onSelectLayer,
    this.onGoToStart,
  });

  final List<String> promptIds;
  final int initialIndex;

  /// 「III」タップ時に呼ぶ（[MainShellState.openPromptDetailInLayer]への参照）。
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
        builder: (_) => Layer2QuestionPromptDetailScreen(
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
  State<Layer2QuestionPromptDetailScreen> createState() =>
      _Layer2QuestionPromptDetailScreenState();
}

class _Layer2QuestionPromptDetailScreenState
    extends State<Layer2QuestionPromptDetailScreen> {
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
        // 「要約」の入力は[TextEditSheet]（showModalBottomSheet）が自前で
        // キーボード分の余白を確保するため、この画面自体はキーボード用に
        // リサイズする必要がない（[Layer3QuestionPromptDetailScreen]と
        // 同じ理由・同じ修正。実機で確認済み）。
        resizeToAvoidBottomInset: false,
        appBar: AppHeader(
          currentIndex: 1,
          onSelect: _handleHeaderSelect,
          onLongPress: _handleHeaderLongPress,
        ),
        body: _Layer2PromptDetailBody(
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

class _Layer2PromptDetailBody extends StatefulWidget {
  const _Layer2PromptDetailBody({
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
  State<_Layer2PromptDetailBody> createState() =>
      _Layer2PromptDetailBodyState();
}

class _Layer2PromptDetailBodyState extends State<_Layer2PromptDetailBody> {
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

  Future<void> _editSummary() async {
    final prompt = _prompt;
    if (prompt == null) return;
    final lang = appSettings.language;
    final edited = await TextEditSheet.show(
      context,
      title: '要約'.tr(lang),
      initialValue: prompt.summary,
      hintText: '要約を入力'.tr(lang),
    );
    if (edited == null || !mounted) return;
    unawaited(_persist(prompt.copyWith(summary: edited)));
  }

  void _showUsageHelp() {
    final lang = appSettings.language;
    LayerHelpSheet.show(
      context,
      title: '操作方法'.tr(lang),
      lines: [
        LayerHelpLine(text: 'レイヤーⅡ_問題文_使い方_要約'.tr(lang)),
        LayerHelpLine(text: 'レイヤーⅡ_問題文_使い方_III'.tr(lang)),
      ],
    );
  }

  void _goToLayer3() {
    final prompt = _prompt;
    if (prompt == null) return;
    Navigator.of(context).pop();
    widget.onOpenPromptDetail?.call(2, prompt.id);
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
                    // 既存の問題文の要約を記入するモードのため、ここからの
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
                    conclusionIcon: Icons.summarize_rounded,
                    conclusionTooltip: '回答の要約',
                    conclusionActive: prompt.summary.isNotEmpty,
                    onConclusionTap: _editSummary,
                    conclusionHintTapText: '回答の要約',
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
                          layerIndex: 2,
                          onTap: _goToLayer3,
                          tooltip: 'レイヤーⅢタイトル'.tr(lang),
                          hintTapText: 'レイヤーⅢタイトル'.tr(lang),
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
