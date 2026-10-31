import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/question_prompt_draw_selection.dart';
import '../../models/question_prompt_filter.dart';
import '../../models/question_prompt_source.dart';
import '../../models/topic_category.dart';
import '../../services/question_prompt_tab_registry.dart';
import '../../theme/app_colors.dart';

/// 問題文一覧のフィルタシート（入手元／カテゴリ／実施状況の3軸）。
/// カテゴリ軸は[QuestionPromptDrawSelectSheet]と同じ選択肢（組み込みタブ・
/// ランダム・シチュエーション）をチップで並べる。
class QuestionPromptFilterSheet extends StatefulWidget {
  const QuestionPromptFilterSheet({
    super.key,
    required this.initial,
    required this.doneAxisLabel,
  });

  final QuestionPromptFilter initial;

  /// 3軸目（実施状況）の見出し。呼び出し元のレイヤーごとに意味が違う
  /// （例：レイヤーⅠは「語彙テスト実施状況」）。
  final String doneAxisLabel;

  static Future<QuestionPromptFilter?> show(
    BuildContext context, {
    required QuestionPromptFilter initial,
    required String doneAxisLabel,
  }) {
    final palette = AppColors.current;
    return showModalBottomSheet<QuestionPromptFilter>(
      context: context,
      backgroundColor: palette.cardFill,
      // 3軸分のチップで既定の高さ制限に収まらないことがあるため、
      // LayerHelpSheetと同じくisScrollControlled+内側スクロールで広げる。
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => QuestionPromptFilterSheet(
        initial: initial,
        doneAxisLabel: doneAxisLabel,
      ),
    );
  }

  @override
  State<QuestionPromptFilterSheet> createState() =>
      _QuestionPromptFilterSheetState();
}

class _QuestionPromptFilterSheetState extends State<QuestionPromptFilterSheet> {
  late QuestionPromptFilter _draft = widget.initial;

  bool _matchesDrawSelection(QuestionPromptDrawSelection selection) {
    if (_draft.category != selection.category) return false;
    return switch (selection.kind) {
      QuestionPromptDrawKind.tagged => _draft.tag == selection.tag,
      QuestionPromptDrawKind.generalRandom =>
        _draft.category == TopicCategory.general && _draft.tag == null,
      QuestionPromptDrawKind.situational => true,
    };
  }

  void _selectDrawSelection(QuestionPromptDrawSelection selection) {
    setState(
      () => _draft = _draft.copyWith(
        category: selection.category,
        tag: selection.filterTag,
        clearTag: selection.filterTag == null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'フィルタ'.tr(lang),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: palette.textOnCardPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FilterSection(
                        title: '入手元'.tr(lang),
                        children: [
                          _FilterChip(
                            label: 'すべて'.tr(lang),
                            selected: _draft.source == null,
                            onTap: () => setState(
                              () => _draft = _draft.copyWith(clearSource: true),
                            ),
                          ),
                          for (final source in QuestionPromptSource.values)
                            _FilterChip(
                              label: _sourceLabel(source).tr(lang),
                              selected: _draft.source == source,
                              onTap: () => setState(
                                () => _draft = _draft.copyWith(source: source),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _FilterSection(
                        title: 'カテゴリ'.tr(lang),
                        children: [
                          _FilterChip(
                            label: 'すべて'.tr(lang),
                            selected: _draft.category == null,
                            onTap: () => setState(
                              () => _draft = _draft.copyWith(
                                clearCategory: true,
                                clearTag: true,
                              ),
                            ),
                          ),
                          for (final tab
                              in QuestionPromptTabRegistry.builtInTabKeys)
                            _FilterChip(
                              label: tab.tr(lang),
                              selected: _matchesDrawSelection(
                                QuestionPromptDrawSelection.tag(tab),
                              ),
                              onTap: () => _selectDrawSelection(
                                QuestionPromptDrawSelection.tag(tab),
                              ),
                            ),
                          _FilterChip(
                            label: 'ランダム'.tr(lang),
                            selected: _matchesDrawSelection(
                              const QuestionPromptDrawSelection.generalRandom(),
                            ),
                            onTap: () => _selectDrawSelection(
                              const QuestionPromptDrawSelection.generalRandom(),
                            ),
                          ),
                          _FilterChip(
                            label: 'シチュエーション'.tr(lang),
                            selected: _matchesDrawSelection(
                              const QuestionPromptDrawSelection.situational(),
                            ),
                            onTap: () => _selectDrawSelection(
                              const QuestionPromptDrawSelection.situational(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _FilterSection(
                        title: widget.doneAxisLabel,
                        children: [
                          _FilterChip(
                            label: 'すべて'.tr(lang),
                            selected: _draft.done == null,
                            onTap: () => setState(
                              () => _draft = _draft.copyWith(clearDone: true),
                            ),
                          ),
                          _FilterChip(
                            label: '済み'.tr(lang),
                            selected: _draft.done == true,
                            onTap: () => setState(
                              () => _draft = _draft.copyWith(done: true),
                            ),
                          ),
                          _FilterChip(
                            label: '未実施'.tr(lang),
                            selected: _draft.done == false,
                            onTap: () => setState(
                              () => _draft = _draft.copyWith(done: false),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  TextButton(
                    onPressed: () =>
                        setState(() => _draft = const QuestionPromptFilter()),
                    child: Text('リセット'.tr(lang)),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_draft),
                    child: Text('完了'.tr(lang)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _sourceLabel(QuestionPromptSource source) => switch (source) {
    QuestionPromptSource.builtIn => '組み込み',
    QuestionPromptSource.ai => 'AI',
    QuestionPromptSource.manual => '手入力',
    QuestionPromptSource.imported => 'インポート',
  };
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: palette.textOnCardSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final fill = selected ? palette.accentColor : Colors.transparent;
    final foreground = selected ? palette.onAccent : palette.textOnCardPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? palette.accentColor : palette.cardBorder,
          ),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, color: foreground)),
      ),
    );
  }
}
