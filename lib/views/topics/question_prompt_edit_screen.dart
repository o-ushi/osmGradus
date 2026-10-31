import 'dart:async';

import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/question_prompt.dart';
import '../../models/question_prompt_draw_selection.dart';
import '../../models/topic_category.dart';
import '../../services/question_prompt_auto_tag_service.dart';
import '../../services/question_prompt_service.dart';
import '../../services/question_prompt_tab_registry.dart';
import '../../theme/app_colors.dart';
import '../../widgets/question_prompt_editor_form.dart';
import '../../widgets/question_prompt_editor_helpers.dart';
import '../../widgets/swipe_to_close_wrapper.dart';

/// 問題文一覧で本文を長押しすると開く編集画面（`question-prompt-tabs.md` Step 5）。
class QuestionPromptEditScreen extends StatefulWidget {
  const QuestionPromptEditScreen({super.key, required this.prompt});

  final QuestionPrompt prompt;

  static Future<void> push(
    BuildContext context, {
    required QuestionPrompt prompt,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => QuestionPromptEditScreen(prompt: prompt),
        transitionDuration: const Duration(milliseconds: 180),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<QuestionPromptEditScreen> createState() =>
      _QuestionPromptEditScreenState();
}

class _QuestionPromptEditScreenState extends State<QuestionPromptEditScreen> {
  final _service = QuestionPromptService();
  final _tabRegistry = QuestionPromptTabRegistry();
  final _autoTagService = QuestionPromptAutoTagService();

  late final _bodyController = TextEditingController(text: widget.prompt.body);
  late final _conditionController = TextEditingController(
    text: widget.prompt.situationCondition ?? '',
  );

  late TopicCategory _category = widget.prompt.category;
  late QuestionPromptDrawSelection _drawSelection =
      QuestionPromptDrawSelection.fromPrompt(widget.prompt);
  late Set<String> _selectedTags = widget.prompt.tags.toSet();
  List<String> _tabKeys = const [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadTabKeys());
  }

  @override
  void dispose() {
    _bodyController.dispose();
    _conditionController.dispose();
    super.dispose();
  }

  Future<void> _loadTabKeys() async {
    final tabKeys = await _tabRegistry.allTabKeys();
    if (!mounted) return;
    setState(() => _tabKeys = tabKeys);
  }

  void _changeDrawSelection(QuestionPromptDrawSelection selection) {
    setState(() {
      _drawSelection = selection;
      if (selection.kind == QuestionPromptDrawKind.situational) {
        _category = TopicCategory.situational;
        _selectedTags = {};
      } else if (selection.kind == QuestionPromptDrawKind.tagged) {
        _category = TopicCategory.general;
        _selectedTags = {selection.tag!};
      } else {
        _category = TopicCategory.general;
        if (widget.prompt.category == TopicCategory.situational) {
          _selectedTags = _autoTagService
              .suggestTags(_bodyController.text.trim())
              .toSet();
        }
      }
    });
  }

  void _toggleTag(String tag) {
    setState(() {
      if (!_selectedTags.remove(tag)) _selectedTags.add(tag);
    });
  }

  Future<void> _addCustomTag() async {
    final lang = appSettings.language;
    final name = await showQuestionPromptNewTagDialog(context, lang);
    if (name == null) return;
    await _tabRegistry.addCustomTab(name);
    final tabKeys = await _tabRegistry.allTabKeys();
    if (!mounted) return;
    setState(() {
      _tabKeys = tabKeys;
      if (tabKeys.contains(name)) _selectedTags.add(name);
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    final lang = appSettings.language;
    final body = _bodyController.text.trim();
    if (body.isEmpty) {
      _showMessage('問題文を入力してください'.tr(lang));
      return;
    }
    if (_category == TopicCategory.general && _selectedTags.isEmpty) {
      _showMessage('タブを1つ以上選択してください'.tr(lang));
      return;
    }
    setState(() => _saving = true);
    final condition = _conditionController.text.trim();
    await _service.updateContent(
      id: widget.prompt.id,
      body: body,
      situationCondition: _category == TopicCategory.situational
          ? (condition.isEmpty ? null : condition)
          : null,
      category: _category,
      tags: _category == TopicCategory.general
          ? _selectedTags.toList()
          : const [],
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  bool get _canSave {
    final body = _bodyController.text.trim();
    if (body.isEmpty || _saving) return false;
    if (_category == TopicCategory.general && _selectedTags.isEmpty) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    return SwipeToCloseWrapper(
      child: Material(
        color: palette.scene,
        child: SafeArea(
          child: Column(
            children: [
              QuestionPromptEditorHeader(
                titleKey: '問題文を編集',
                lang: lang,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    QuestionPromptEditorForm(
                      lang: lang,
                      drawSelection: _drawSelection,
                      onDrawSelectionChanged: _changeDrawSelection,
                      showRandomInCategory: false,
                      bodyController: _bodyController,
                      conditionController: _conditionController,
                      category: _category,
                      tabKeys: _tabKeys,
                      selectedTags: _selectedTags,
                      onToggleTag: _toggleTag,
                      onAddCustomTag: _addCustomTag,
                      submitIcon: Icons.check_rounded,
                      submitTooltipKey: '保存',
                      onSubmit: _save,
                      canSubmit: _canSave,
                      isSubmitting: _saving,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
