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
import '../../widgets/question_prompt_list_row.dart';
import 'question_prompt_filter_sheet.dart';
import 'topic_add_flow.dart';

/// 問題文一覧（レイヤーⅠ〜Ⅴ共通）。進捗度＋フィルタアイコンを上部に置き、
/// 「理解」列（レイヤーⅠ、Step 2）のように、実施状況の意味はレイヤーごとに
/// [isDone]・[doneAxisLabel]で差し替える。行タップで[onTap]を呼ぶだけで、
/// 詳細画面への遷移方法（inline切替／Navigator.push）は呼び出し側に任せる。
class QuestionPromptListScreen extends StatefulWidget {
  const QuestionPromptListScreen({
    super.key,
    required this.title,
    required this.progressLabel,
    required this.doneAxisLabel,
    required this.isDone,
    required this.onTap,
    this.trailingBuilder,
  });

  final String title;

  /// 進捗行の見出し（例：レイヤーⅠは「理解」）。
  final String progressLabel;

  /// フィルタシートの3軸目の見出し。
  final String doneAxisLabel;

  /// 進捗・フィルタ・行の実施状況アイコンで使う判定。
  final bool Function(QuestionPrompt) isDone;

  /// 行タップ時に呼ぶ。[orderedPrompts]は、タップ時点のフィルタ条件で絞り込んだ
  /// 表示順そのままの一覧（詳細画面の上下スワイプでの前後移動に使う）。
  final void Function(
    BuildContext context,
    QuestionPrompt prompt,
    List<QuestionPrompt> orderedPrompts,
  )
  onTap;

  /// 行の右端に的中度・PREPスコア等の列を追加したいとき（Step 3〜6）。
  final Widget? Function(QuestionPrompt)? trailingBuilder;

  @override
  State<QuestionPromptListScreen> createState() =>
      QuestionPromptListScreenState();
}

class QuestionPromptListScreenState extends State<QuestionPromptListScreen> {
  final _service = QuestionPromptService();
  List<QuestionPrompt> _all = [];
  bool _loading = true;
  QuestionPromptFilter _filter = const QuestionPromptFilter();

  @override
  void initState() {
    super.initState();
    unawaited(reload());
  }

  Future<void> reload() async {
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
      doneAxisLabel: widget.doneAxisLabel.tr(lang),
    );
    if (picked == null || !mounted) return;
    setState(() => _filter = picked);
  }

  /// 「＋」タップ：レイヤーⅡ〜Ⅳの「＋」と同じ、AI取込／手入力／JSON
  /// 取込・書き出しの選択シートへ（[showTopicAddChoiceFlow]、Step 1で
  /// 確立した[TopicService]→[QuestionPromptService]のミラー経由で反映される）。
  /// この一覧は分野をまたぐため、追加後にどの分野を選んでいたかに関わらず
  /// 日常会話をデフォルトにする。
  Future<void> _addPrompt() async {
    await showTopicAddChoiceFlow(context, initialCategory: TopicCategory.daily);
    await reload();
  }

  /// 「＋」長押し：この一覧画面自体（フィルタ・追加・削除・詳細）の使い方。
  void _showUsageHelp() {
    final lang = appSettings.language;
    LayerHelpSheet.show(
      context,
      title: '操作方法'.tr(lang),
      lines: [
        LayerHelpLine(text: '問題文一覧_使い方_追加'.tr(lang), icon: Icons.add),
        LayerHelpLine(text: '問題文一覧_使い方_フィルタ'.tr(lang), icon: Icons.filter_list),
        LayerHelpLine(text: '問題文一覧_使い方_詳細'.tr(lang)),
        LayerHelpLine(text: '問題文一覧_使い方_削除'.tr(lang)),
      ],
    );
  }

  Future<void> _deletePrompt(QuestionPrompt prompt) async {
    await _service.delete(prompt.id);
    if (!mounted) return;
    setState(() => _all = _all.where((p) => p.id != prompt.id).toList());
  }

  /// 組み込みの問題文は[QuestionPromptService.loadAll]が毎回補充するため、
  /// 削除しても即座に復元されてしまう。スワイプ自体は受け付けつつ、
  /// 確認ダイアログの前に案内して削除を行わない。
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

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    final filtered = _service
        .filter(_all, category: _filter.category, source: _filter.source)
        .where((p) => _filter.done == null || widget.isDone(p) == _filter.done)
        .toList();
    final doneCount = _all.where(widget.isDone).length;
    final total = _all.length;
    final percent = total == 0 ? 0 : (doneCount * 100 / total).round();

    return Container(
      color: palette.scene,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title.tr(lang),
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
                    widget.progressLabel.tr(lang),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: palette.textOnSceneSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '進捗_件数割合'.trFmt(lang, ['$doneCount', '$total', '$percent']),
                    style: TextStyle(
                      fontSize: 13,
                      color: palette.textOnSceneSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                    ? Center(
                        child: Text(
                          '問題文がありません'.tr(lang),
                          style: TextStyle(color: palette.textOnSceneSecondary),
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
                            child: QuestionPromptListRow(
                              done: widget.isDone(prompt),
                              body: prompt.body,
                              onTap: () =>
                                  widget.onTap(context, prompt, filtered),
                              trailing: widget.trailingBuilder?.call(prompt),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
