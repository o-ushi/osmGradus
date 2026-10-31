import 'dart:async';

import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/question_prompt_draw_selection.dart';
import '../../models/question_prompt_source.dart';
import '../../models/topic_category.dart';
import '../../services/question_prompt_auto_tag_service.dart';
import '../../services/question_prompt_service.dart';
import '../../services/question_prompt_tab_registry.dart';
import '../../services/topic_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/question_prompt_editor_form.dart';
import '../../widgets/question_prompt_editor_helpers.dart';
import '../../widgets/swipe_to_close_wrapper.dart';

/// [TopicImportScreen]（AI取り込み）に対する、キーボードでの手動追加版。
class TopicManualAddScreen extends StatefulWidget {
  const TopicManualAddScreen({super.key, required this.initialCategory});

  final TopicCategory initialCategory;

  static Future<void> push(
    BuildContext context, {
    required TopicCategory initialCategory,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) =>
            TopicManualAddScreen(initialCategory: initialCategory),
        transitionDuration: const Duration(milliseconds: 180),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<TopicManualAddScreen> createState() => _TopicManualAddScreenState();
}

class _TopicManualAddScreenState extends State<TopicManualAddScreen> {
  final _service = TopicService();
  final _promptService = QuestionPromptService();
  final _tabRegistry = QuestionPromptTabRegistry();
  final _autoTagService = QuestionPromptAutoTagService();
  final _bodyController = TextEditingController();
  final _conditionController = TextEditingController();

  late QuestionPromptDrawSelection _drawSelection =
      QuestionPromptDrawSelection.fromTopicCategory(
        normalizeToGeneral(widget.initialCategory),
      );
  late Set<String> _selectedTags = _initialTags();
  List<String> _tabKeys = const [];

  int _count = 0;
  String? _resultMessage;
  bool _resultIsError = false;
  bool _adding = false;

  TopicCategory get _category => _drawSelection.category;

  Set<String> _initialTags() {
    if (_drawSelection.kind == QuestionPromptDrawKind.tagged) {
      return {_drawSelection.tag!};
    }
    return {};
  }

  @override
  void initState() {
    super.initState();
    _bodyController.addListener(_onBodyChanged);
    unawaited(_loadTabKeys());
    unawaited(_loadCount());
  }

  @override
  void dispose() {
    _bodyController
      ..removeListener(_onBodyChanged)
      ..dispose();
    _conditionController.dispose();
    super.dispose();
  }

  void _onBodyChanged() => setState(() {});

  Future<void> _loadTabKeys() async {
    final tabKeys = await _tabRegistry.allTabKeys();
    if (!mounted) return;
    setState(() => _tabKeys = tabKeys);
  }

  Future<void> _loadCount() async {
    final imported = await _service.loadImported(_category);
    if (!mounted) return;
    setState(() => _count = imported.length);
  }

  void _changeDrawSelection(QuestionPromptDrawSelection selection) {
    setState(() {
      _drawSelection = selection;
      _resultMessage = null;
      if (selection.kind == QuestionPromptDrawKind.situational) {
        _selectedTags = {};
      } else if (selection.kind == QuestionPromptDrawKind.tagged) {
        _selectedTags = {selection.tag!};
      } else if (_selectedTags.isEmpty) {
        _selectedTags = _autoTagService
            .suggestTags(_bodyController.text.trim())
            .toSet();
      }
    });
    unawaited(_loadCount());
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

  List<String> Function(String body)? get _tagsForBody {
    if (_category == TopicCategory.situational) return null;
    if (_selectedTags.isNotEmpty) return (_) => _selectedTags.toList();
    return switch (_drawSelection.kind) {
      QuestionPromptDrawKind.tagged => (_) => [_drawSelection.tag!],
      QuestionPromptDrawKind.generalRandom => _autoTagService.suggestTags,
      QuestionPromptDrawKind.situational => null,
    };
  }

  Future<void> _add() async {
    final lang = appSettings.language;
    final body = _bodyController.text.trim();
    if (body.isEmpty) return;
    if (_category == TopicCategory.general) {
      final tags = _tagsForBody?.call(body) ?? const <String>[];
      if (tags.isEmpty) {
        setState(() {
          _resultIsError = true;
          _resultMessage = 'タブを1つ以上選択してください';
        });
        return;
      }
    }

    setState(() {
      _adding = true;
      _resultMessage = null;
    });
    final added = await _service.importTopics(
      _category,
      [body],
      source: QuestionPromptSource.manual,
      tagsForBody: _tagsForBody,
    );
    if (!mounted) return;

    if (added == 0) {
      setState(() {
        _adding = false;
        _resultIsError = true;
        _resultMessage = 'このお題はすでに追加されています。';
      });
      return;
    }

    if (_category == TopicCategory.situational) {
      final condition = _conditionController.text.trim();
      if (condition.isNotEmpty) {
        final all = await _promptService.loadAll();
        final prompt = all.lastWhere(
          (p) =>
              p.category == TopicCategory.situational &&
              p.body == body &&
              p.source == QuestionPromptSource.manual,
        );
        await _promptService.updateContent(
          id: prompt.id,
          body: body,
          situationCondition: condition,
          category: TopicCategory.situational,
          tags: const [],
        );
      }
    }

    _bodyController.clear();
    _conditionController.clear();
    await _loadCount();
    if (!mounted) return;
    setState(() {
      _adding = false;
      _resultIsError = false;
      _resultMessage = 'お題を追加しました。';
    });
  }

  bool get _canAdd {
    final body = _bodyController.text.trim();
    return body.isNotEmpty && !_adding;
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
                titleKey: 'お題を自分で追加',
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
                      showRandomInCategory: true,
                      bodyController: _bodyController,
                      conditionController: _conditionController,
                      category: _category,
                      tabKeys: _tabKeys,
                      selectedTags: _selectedTags,
                      onToggleTag: _toggleTag,
                      onAddCustomTag: _addCustomTag,
                      submitIcon: Icons.add_rounded,
                      submitTooltipKey: '追加',
                      onSubmit: _add,
                      canSubmit: _canAdd,
                      isSubmitting: _adding,
                      bodyHintKey: 'お題を入力',
                      statusMessage: _resultMessage,
                      statusIsError: _resultIsError,
                      footer: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '追加済みのお題'.tr(lang),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: palette.textOnCardPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '%lld 件'.trFmt(lang, [_count.toString()]),
                            style: TextStyle(
                              fontSize: 13,
                              color: palette.textOnCardSecondary,
                            ),
                          ),
                        ],
                      ),
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
