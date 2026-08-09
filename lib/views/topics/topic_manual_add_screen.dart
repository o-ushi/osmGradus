import 'dart:async';

import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/topic_category.dart';
import '../../services/topic_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ai_import_shared.dart';
import '../../widgets/category_select_field.dart';
import '../../widgets/swipe_to_close_wrapper.dart';

/// [TopicImportScreen]（AI取り込み）に対する、キーボードでの手動追加版。
/// 分野を選んでテキストを1件ずつ入力し、[TopicService.importTopics]と
/// 同じ保存先へそのまま追加する（サイコロで引く側は取り込み経路を問わない）。
class TopicManualAddScreen extends StatefulWidget {
  const TopicManualAddScreen({super.key, required this.initialCategory});

  /// 呼び出し元レイヤーで選択中だった分野。「ランダム」は保存先を持たない
  /// ため、その場合は日常会話にフォールバックする（[_selectableCategories]）。
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
  static const _selectableCategories = [
    TopicCategory.daily,
    TopicCategory.business,
    TopicCategory.situational,
  ];

  final _service = TopicService();
  final _textController = TextEditingController();

  late TopicCategory _category =
      _selectableCategories.contains(widget.initialCategory)
      ? widget.initialCategory
      : TopicCategory.daily;

  int _count = 0;
  String? _resultMessage;
  bool _resultIsError = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCount());
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadCount() async {
    final imported = await _service.loadImported(_category);
    if (!mounted) return;
    setState(() => _count = imported.length);
  }

  void _changeCategory(TopicCategory category) {
    setState(() {
      _category = category;
      _resultMessage = null;
    });
    unawaited(_loadCount());
  }

  Future<void> _add() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final added = await _service.importTopics(_category, [text]);
    if (!mounted) return;
    if (added == 0) {
      setState(() {
        _resultIsError = true;
        _resultMessage = 'このお題はすでに追加されています。';
      });
      return;
    }
    _textController.clear();
    await _loadCount();
    if (!mounted) return;
    setState(() {
      _resultIsError = false;
      _resultMessage = 'お題を追加しました。';
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    final canAdd = _textController.text.trim().isNotEmpty;
    return SwipeToCloseWrapper(
      child: Material(
        color: palette.scene,
        child: SafeArea(
          child: Column(
            children: [
              AiImportHeader(title: 'お題を自分で追加'.tr(lang), lang: lang),
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
                            availableCategories: _selectableCategories,
                            onCardBackground: true,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _textController,
                            minLines: 2,
                            maxLines: 6,
                            onChanged: (_) => setState(() {}),
                            style: TextStyle(
                              color: palette.textOnCardPrimary,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: 'お題を入力'.tr(lang),
                              hintStyle: TextStyle(
                                color: palette.textOnCardSecondary,
                              ),
                              filled: true,
                              fillColor: palette.subpageBackground,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: QuickActionButton(
                              icon: Icons.add,
                              label: '追加'.tr(lang),
                              onTap: canAdd ? _add : null,
                              filled: true,
                            ),
                          ),
                          if (_resultMessage != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _resultMessage!.tr(lang),
                              style: TextStyle(
                                fontSize: 12,
                                color: _resultIsError
                                    ? Colors.orange
                                    : Colors.green,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Divider(color: palette.cardBorder),
                          const SizedBox(height: 8),
                          Row(
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
