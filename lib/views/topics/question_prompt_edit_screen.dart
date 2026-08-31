import 'dart:async';

import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/question_prompt.dart';
import '../../models/topic_category.dart';
import '../../services/question_prompt_auto_tag_service.dart';
import '../../services/question_prompt_service.dart';
import '../../services/question_prompt_tab_registry.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ai_import_shared.dart';
import '../../widgets/category_select_field.dart';
import '../../widgets/swipe_to_close_wrapper.dart';

/// 問題文一覧で本文を長押しすると開く編集画面（`question-prompt-tabs.md` Step 5）。
/// 本文（シチュエーションは状況＋条件の2欄）とカテゴリ・タブを編集し、
/// [QuestionPromptService.updateContent]で保存する。組み込み
/// （[QuestionPromptSource.builtIn]）の問題文も編集対象。
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
  static const _availableCategories = [
    TopicCategory.general,
    TopicCategory.situational,
  ];

  final _service = QuestionPromptService();
  final _tabRegistry = QuestionPromptTabRegistry();
  final _autoTagService = QuestionPromptAutoTagService();

  late final _bodyController = TextEditingController(text: widget.prompt.body);
  late final _conditionController = TextEditingController(
    text: widget.prompt.situationCondition ?? '',
  );

  late TopicCategory _category = widget.prompt.category;
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

  void _changeCategory(TopicCategory category) {
    setState(() {
      if (category == TopicCategory.situational) {
        _selectedTags = {};
      } else if (_category == TopicCategory.situational) {
        _selectedTags = _autoTagService
            .suggestTags(_bodyController.text.trim())
            .toSet();
      }
      _category = category;
    });
  }

  void _toggleTag(String tag) {
    setState(() {
      if (!_selectedTags.remove(tag)) _selectedTags.add(tag);
    });
  }

  Future<void> _addCustomTag() async {
    final lang = appSettings.language;
    final name = await _showNewTagDialog(lang);
    if (name == null) return;
    await _tabRegistry.addCustomTab(name);
    final tabKeys = await _tabRegistry.allTabKeys();
    if (!mounted) return;
    setState(() {
      _tabKeys = tabKeys;
      if (tabKeys.contains(name)) _selectedTags.add(name);
    });
  }

  Future<String?> _showNewTagDialog(String lang) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('新しいタブ'.tr(lang)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: QuestionPromptTabRegistry.maxTabNameLength,
          decoration: InputDecoration(hintText: 'タブ名を入力'.tr(lang)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('キャンセル'.tr(lang)),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text('追加'.tr(lang)),
          ),
        ],
      ),
    ).then((value) => value == null || value.isEmpty ? null : value);
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

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    final isSituational = _category == TopicCategory.situational;
    return SwipeToCloseWrapper(
      child: Material(
        color: palette.scene,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '問題文を編集'.tr(lang),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: palette.textOnScenePrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close,
                        color: palette.textOnScenePrimary,
                      ),
                      tooltip: 'キャンセル'.tr(lang),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    AiImportCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CategorySelectField(
                            selected: _category,
                            onChanged: _changeCategory,
                            availableCategories: _availableCategories,
                            onCardBackground: true,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            (isSituational ? '状況' : '本文').tr(lang),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: palette.textOnCardSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _bodyController,
                            minLines: 3,
                            maxLines: 8,
                            style: TextStyle(
                              color: palette.textOnCardPrimary,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: palette.subpageBackground,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          if (isSituational) ...[
                            const SizedBox(height: 12),
                            Text(
                              '条件'.tr(lang),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: palette.textOnCardSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _conditionController,
                              minLines: 2,
                              maxLines: 6,
                              style: TextStyle(
                                color: palette.textOnCardPrimary,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: palette.subpageBackground,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ],
                          if (!isSituational) ...[
                            const SizedBox(height: 16),
                            Text(
                              'タブ'.tr(lang),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: palette.textOnCardPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final tabKey in _tabKeys)
                                  FilterChip(
                                    label: Text(tabKey.tr(lang)),
                                    selected: _selectedTags.contains(tabKey),
                                    onSelected: (_) => _toggleTag(tabKey),
                                    selectedColor: palette.accentColor
                                        .withValues(alpha: 0.24),
                                    checkmarkColor: palette.accentColor,
                                    backgroundColor: palette.subpageBackground,
                                    labelStyle: TextStyle(
                                      color: palette.textOnCardPrimary,
                                    ),
                                    side: BorderSide(color: palette.cardBorder),
                                  ),
                                ActionChip(
                                  avatar: Icon(
                                    Icons.add,
                                    size: 18,
                                    color: palette.textOnCardPrimary,
                                  ),
                                  label: Text('新しいタブ'.tr(lang)),
                                  onPressed: _addCustomTag,
                                  backgroundColor: palette.subpageBackground,
                                  labelStyle: TextStyle(
                                    color: palette.textOnCardPrimary,
                                  ),
                                  side: BorderSide(color: palette.cardBorder),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: QuickActionButton(
                              icon: Icons.check,
                              label: '保存'.tr(lang),
                              onTap: _saving ? null : _save,
                              filled: true,
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
