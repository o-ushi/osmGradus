import 'dart:async';

import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/question_prompt.dart';
import '../../models/question_prompt_filter.dart';
import '../../models/question_prompt_source.dart';
import '../../models/topic_category.dart';
import '../../services/question_prompt_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/confirm_history_delete_dialog.dart';
import '../../widgets/history_delete_background.dart';
import '../../widgets/layer_help_sheet.dart';
import '../../widgets/layer_numeral_badge.dart';
import '../../widgets/question_prompt_overview_row.dart';
import '../../widgets/swipe_to_close_wrapper.dart';
import '../layers/layer1_question_prompt_detail_screen.dart';
import '../layers/layer2_question_prompt_detail_screen.dart';
import '../layers/layer3_question_prompt_detail_screen.dart';
import '../layers/layer4_question_prompt_detail_screen.dart';
import '../layers/layer5_question_prompt_detail_screen.dart';
import '../layers/question_prompt_summary_screen.dart';
import 'question_prompt_filter_sheet.dart';
import 'topic_add_flow.dart';

/// 起動画面から開く横断問題文一覧（Step 9）。
///
/// 各行は `総評 | Ⅰ | Ⅱ | Ⅲ | Ⅳ | Ⅴ | 本文`。総評列の ⭕️（Ⅰ〜Ⅴの
/// いずれか実施済み、またはアドバイス取得済み）をタップすると
/// [QuestionPromptSummaryScreen]を開く。Ⅰ〜Ⅴのマークをタップすると、
/// **この一覧の上に**該当レイヤーの問題文詳細をpushする（一覧は残すので、
/// 詳細で右スワイプするとこの一覧に戻れる）。レイヤー別一覧
/// （[QuestionPromptListScreen]）とは列構成が違うため、専用画面にする。
class QuestionPromptOverviewScreen extends StatefulWidget {
  const QuestionPromptOverviewScreen({super.key, this.onOpenLayer});

  /// 詳細画面の[AppHeader]「Ⅰ」〜「Ⅴ」タップ時。詳細は自身をpopしたあと
  /// この一覧も閉じて、起動画面側でMainShellの該当レイヤーを開く。
  final void Function(int index)? onOpenLayer;

  static Future<void> push(
    BuildContext context, {
    void Function(int index)? onOpenLayer,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuestionPromptOverviewScreen(onOpenLayer: onOpenLayer),
      ),
    );
  }

  @override
  State<QuestionPromptOverviewScreen> createState() =>
      _QuestionPromptOverviewScreenState();
}

class _QuestionPromptOverviewScreenState
    extends State<QuestionPromptOverviewScreen> {
  final _service = QuestionPromptService();
  List<QuestionPrompt> _all = [];
  bool _loading = true;
  QuestionPromptFilter _filter = const QuestionPromptFilter();

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final all = await _service.loadAll();
    if (!mounted) return;
    setState(() {
      _all = all;
      _loading = false;
    });
  }

  Future<void> _openFilterSheet() async {
    final lang = appSettings.language;
    final picked = await QuestionPromptFilterSheet.show(
      context,
      initial: _filter,
      doneAxisLabel: '総評実施状況'.tr(lang),
    );
    if (picked == null || !mounted) return;
    setState(() => _filter = picked);
  }

  Future<void> _addPrompt() async {
    await showTopicAddChoiceFlow(context, initialCategory: TopicCategory.daily);
    await _reload();
  }

  void _showUsageHelp() {
    final lang = appSettings.language;
    LayerHelpSheet.show(
      context,
      title: '操作方法'.tr(lang),
      lines: [
        LayerHelpLine(text: '問題文一覧_使い方_追加'.tr(lang), icon: Icons.add),
        LayerHelpLine(text: '問題文一覧_使い方_フィルタ'.tr(lang), icon: Icons.filter_list),
        LayerHelpLine(text: '問題文横断一覧_使い方_総評'.tr(lang)),
        LayerHelpLine(text: '問題文横断一覧_使い方_レイヤー'.tr(lang)),
        LayerHelpLine(text: '問題文一覧_使い方_削除'.tr(lang)),
      ],
    );
  }

  Future<void> _deletePrompt(QuestionPrompt prompt) async {
    await _service.delete(prompt.id);
    if (!mounted) return;
    setState(() => _all = _all.where((p) => p.id != prompt.id).toList());
  }

  Future<bool> _confirmDismiss(QuestionPrompt prompt) async {
    final lang = appSettings.language;
    if (prompt.source == QuestionPromptSource.builtIn) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('標準問題文は削除できません'.tr(lang))));
      }
      return false;
    }
    return confirmHistoryDelete(context, languageCode: lang);
  }

  Future<void> _openSummary(QuestionPrompt prompt) async {
    await QuestionPromptSummaryScreen.push(context, promptId: prompt.id);
    await _reload();
  }

  /// 詳細のII〜Vボタンから。詳細は既に自身をpop済みなので、
  /// この一覧の上に次レイヤー詳細を載せる（一覧は残したまま）。
  void _onOpenPromptDetailFromDetail(int layerIndex, String promptId) {
    unawaited(_pushLayerDetail(layerIndex, promptId));
  }

  /// 詳細の[AppHeader]から。詳細は既にpop済み。一覧も閉じてMainShellへ。
  void _onSelectLayerFromDetail(int index) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    widget.onOpenLayer?.call(index);
  }

  void _onGoToSummary(String promptId) {
    unawaited(QuestionPromptSummaryScreen.push(context, promptId: promptId));
  }

  /// 詳細画面の常設[AppHeader]のいずれかのボタン長押しから。詳細は既に
  /// 自身をpop済みなので、この一覧画面も閉じて起動画面（スタート画面）へ戻る
  /// （[QuestionPromptOverviewScreen]自体が起動画面から直接pushされているため、
  /// これを閉じるだけで起動画面が現れる。[_onSelectLayerFromDetail]と違い、
  /// レイヤーを開き直しはしない）。
  void _onGoToStartFromDetail() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  /// Ⅰ〜Ⅴマークタップ：一覧の上に詳細をpush（右スワイプで一覧に戻れる）。
  void _openLayerDetail(int layerIndex, QuestionPrompt prompt) {
    unawaited(_pushLayerDetail(layerIndex, prompt.id));
  }

  Future<void> _pushLayerDetail(int layerIndex, String promptId) async {
    if (!mounted) return;
    switch (layerIndex) {
      case 0:
        await Layer1QuestionPromptDetailScreen.push(
          context,
          promptIds: [promptId],
          initialIndex: 0,
          onOpenPromptDetail: _onOpenPromptDetailFromDetail,
          onSelectLayer: _onSelectLayerFromDetail,
          onGoToStart: _onGoToStartFromDetail,
        );
      case 1:
        await Layer2QuestionPromptDetailScreen.push(
          context,
          promptIds: [promptId],
          initialIndex: 0,
          onOpenPromptDetail: _onOpenPromptDetailFromDetail,
          onSelectLayer: _onSelectLayerFromDetail,
          onGoToStart: _onGoToStartFromDetail,
        );
      case 2:
        await Layer3QuestionPromptDetailScreen.push(
          context,
          promptIds: [promptId],
          initialIndex: 0,
          onOpenPromptDetail: _onOpenPromptDetailFromDetail,
          onSelectLayer: _onSelectLayerFromDetail,
          onGoToStart: _onGoToStartFromDetail,
        );
      case 3:
        await Layer4QuestionPromptDetailScreen.push(
          context,
          promptIds: [promptId],
          initialIndex: 0,
          onOpenPromptDetail: _onOpenPromptDetailFromDetail,
          onSelectLayer: _onSelectLayerFromDetail,
          onGoToStart: _onGoToStartFromDetail,
        );
      case 4:
        await Layer5QuestionPromptDetailScreen.push(
          context,
          promptIds: [promptId],
          initialIndex: 0,
          onSelectLayer: _onSelectLayerFromDetail,
          onGoToStart: _onGoToStartFromDetail,
          onGoToSummary: _onGoToSummary,
        );
    }
    await _reload();
  }

  List<QuestionPrompt> get _filtered => _service
      .filter(_all, field: _filter.field, source: _filter.source)
      .where(
        (p) =>
            _filter.done == null ||
            p.showsOverviewSummaryMarker == _filter.done,
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    final filtered = _filtered;
    final doneCount = _all.where((p) => p.showsOverviewSummaryMarker).length;
    final total = _all.length;
    final percent = total == 0 ? 0 : (doneCount * 100 / total).round();

    return SwipeToCloseWrapper(
      child: Scaffold(
        backgroundColor: palette.scene,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '問題文一覧'.tr(lang),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: palette.textOnScenePrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _openFilterSheet,
                      icon: Icon(
                        Icons.filter_list,
                        color: _filter.isEmpty
                            ? palette.textOnScenePrimary
                            : palette.accentColor,
                      ),
                      tooltip: 'フィルタ'.tr(lang),
                    ),
                    Tooltip(
                      message: '問題文を追加'.tr(lang),
                      triggerMode: TooltipTriggerMode.manual,
                      child: InkWell(
                        onTap: _addPrompt,
                        onLongPress: _showUsageHelp,
                        customBorder: const CircleBorder(),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.add,
                            color: palette.textOnScenePrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      '総評'.tr(lang),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: palette.textOnSceneSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '進捗_件数割合'.trFmt(lang, [
                        '$doneCount',
                        '$total',
                        '$percent',
                      ]),
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.textOnSceneSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const _OverviewHeader(),
                const SizedBox(height: 4),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : filtered.isEmpty
                      ? Center(
                          child: Text(
                            '問題文がありません'.tr(lang),
                            style: TextStyle(
                              color: palette.textOnSceneSecondary,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            color: palette.textOnSceneSecondary.withValues(
                              alpha: 0.15,
                            ),
                          ),
                          itemBuilder: (context, index) {
                            final prompt = filtered[index];
                            return Dismissible(
                              key: ValueKey(prompt.id),
                              direction: DismissDirection.endToStart,
                              background: const HistoryDeleteBackground(),
                              confirmDismiss: (_) => _confirmDismiss(prompt),
                              onDismissed: (_) => _deletePrompt(prompt),
                              child: QuestionPromptOverviewRow(
                                prompt: prompt,
                                onSummaryTap: () => _openSummary(prompt),
                                onLayerTap: (layerIndex) =>
                                    _openLayerDetail(layerIndex, prompt),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader();

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    final style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: palette.textOnSceneSecondary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '総評'.tr(lang),
              textAlign: TextAlign.center,
              style: style,
            ),
          ),
          for (var i = 0; i < 5; i++)
            SizedBox(
              width: QuestionPromptOverviewRow.layerColumnWidth,
              child: Center(child: LayerNumeralIcon(layerIndex: i, size: 22)),
            ),
          Expanded(child: Text('本文'.tr(lang), style: style)),
        ],
      ),
    );
  }
}
