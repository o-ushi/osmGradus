import 'dart:async';

import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../services/question_prompt_service.dart';
import '../../services/question_prompt_tab_registry.dart';
import '../../theme/app_colors.dart';
import '../../widgets/osm_subpage_scaffold.dart';
import '../../widgets/question_prompt_editor_helpers.dart';
import '../../widgets/settings_section.dart';

/// 設定画面から開く、問題文タブ（組み込み＋独自）の一括管理画面。
class QuestionPromptTabSettingsScreen extends StatefulWidget {
  const QuestionPromptTabSettingsScreen({super.key});

  static Future<void> push(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const QuestionPromptTabSettingsScreen(),
      ),
    );
  }

  @override
  State<QuestionPromptTabSettingsScreen> createState() =>
      _QuestionPromptTabSettingsScreenState();
}

class _QuestionPromptTabSettingsScreenState
    extends State<QuestionPromptTabSettingsScreen> {
  final _registry = QuestionPromptTabRegistry();
  final _promptService = QuestionPromptService();

  List<String> _customTabs = const [];
  final Map<String, int> _usageCounts = {};
  bool _loading = true;

  String get _lang => appSettings.language;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final customTabs = await _registry.customTabKeys();
    final counts = <String, int>{};
    for (final tab in customTabs) {
      counts[tab] = await _promptService.countPromptsWithTag(tab);
    }
    if (!mounted) return;
    setState(() {
      _customTabs = customTabs;
      _usageCounts
        ..clear()
        ..addAll(counts);
      _loading = false;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message.tr(_lang))));
  }

  Future<void> _renameTab(String oldName) async {
    final controller = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('タブ名を変更'.tr(_lang)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: QuestionPromptTabRegistry.maxTabNameLength,
          decoration: InputDecoration(hintText: 'タブ名を入力'.tr(_lang)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('キャンセル'.tr(_lang)),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text('保存'.tr(_lang)),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == oldName) return;

    final renamed = await _registry.renameCustomTab(oldName, newName);
    if (!renamed) {
      if (!mounted) return;
      _showMessage('タブ名が既に使われています');
      return;
    }
    await _promptService.renameTagOnAllPrompts(oldName, newName);
    if (!mounted) return;
    _showMessage('タブを変更しました');
    await _reload();
  }

  Future<void> _deleteTab(String name) async {
    final count = _usageCounts[name] ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('タブを削除'.tr(_lang)),
        content: Text(
          count > 0
              ? 'タブ_削除確認_使用中'.trFmt(_lang, [name, '$count'])
              : 'タブ_削除確認'.trFmt(_lang, [name]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('キャンセル'.tr(_lang)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('削除'.tr(_lang)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final deleted = await _registry.deleteCustomTab(name);
    if (!deleted) return;
    await _promptService.removeTagFromAllPrompts(name);
    if (!mounted) return;
    _showMessage('タブを削除しました');
    await _reload();
  }

  Future<void> _addTab() async {
    final name = await showQuestionPromptNewTagDialog(context, _lang);
    if (name == null) return;
    await _registry.addCustomTab(name);
    if (!mounted) return;
    _showMessage('タブを追加しました');
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final lang = _lang;
    final palette = AppColors.current;
    return OsmSubpageScaffold(
      title: Text('問題文タブの管理'.tr(lang)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                SettingsNoteText('問題文タブ_管理説明'.tr(lang)),
                SettingsSectionHeader(
                  '組み込みタブ'.tr(lang),
                  icon: Icons.lock_outline,
                ),
                SettingsSectionCard(
                  children: [
                    for (var i = 0;
                        i < QuestionPromptTabRegistry.builtInTabKeys.length;
                        i++) ...[
                      if (i > 0) const SettingsItemDivider(),
                      _BuiltInTabRow(
                        label: QuestionPromptTabRegistry.builtInTabKeys[i].tr(
                          lang,
                        ),
                      ),
                    ],
                  ],
                ),
                SettingsSectionHeader(
                  '独自タブ'.tr(lang),
                  icon: Icons.edit_outlined,
                ),
                SettingsSectionCard(
                  children: [
                    if (_customTabs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Text(
                          '独自タブはまだありません'.tr(lang),
                          style: TextStyle(
                            fontSize: 15,
                            color: palette.textOnCardSecondary,
                          ),
                        ),
                      )
                    else
                      for (var i = 0; i < _customTabs.length; i++) ...[
                        if (i > 0) const SettingsItemDivider(),
                        _CustomTabRow(
                          label: _customTabs[i].tr(lang),
                          usageCount: _usageCounts[_customTabs[i]] ?? 0,
                          lang: lang,
                          onRename: () => _renameTab(_customTabs[i]),
                          onDelete: () => _deleteTab(_customTabs[i]),
                        ),
                      ],
                    const SettingsItemDivider(),
                    SettingsNavigationRow(
                      label: '新しいタブ'.tr(lang),
                      leading: Icon(
                        Icons.add_circle_outline,
                        color: palette.accentColor,
                        size: 22,
                      ),
                      onTap: _addTab,
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _BuiltInTabRow extends StatelessWidget {
  const _BuiltInTabRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 17, color: palette.textOnCardPrimary),
            ),
          ),
          Text(
            '組み込み'.tr(appSettings.language),
            style: TextStyle(fontSize: 13, color: palette.textOnCardSecondary),
          ),
        ],
      ),
    );
  }
}

class _CustomTabRow extends StatelessWidget {
  const _CustomTabRow({
    required this.label,
    required this.usageCount,
    required this.lang,
    required this.onRename,
    required this.onDelete,
  });

  final String label;
  final int usageCount;
  final String lang;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 17,
                    color: palette.textOnCardPrimary,
                  ),
                ),
                if (usageCount > 0)
                  Text(
                    'タブ_使用件数'.trFmt(lang, ['$usageCount']),
                    style: TextStyle(
                      fontSize: 13,
                      color: palette.textOnCardSecondary,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRename,
            icon: Icon(Icons.edit_outlined, color: palette.textOnCardPrimary),
            tooltip: 'タブ名を変更'.tr(lang),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'タブを削除'.tr(lang),
          ),
        ],
      ),
    );
  }
}
