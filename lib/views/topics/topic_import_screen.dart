import 'package:flutter/material.dart';

import '../../data/ai_prompt_template.dart';
import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/question_prompt_source.dart';
import '../../models/topic_category.dart';
import '../../services/topic_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ai_import_shared.dart';
import '../../widgets/swipe_to_close_wrapper.dart';

/// osmWashabeの「お題の取り込み」画面（`WashabeTopicImportView`）の丸ごと移植。
/// 「Chrome AIで開く → 回答をコピー → 読み込む → 取り込む」という動線、
/// AIプロンプトの表示、取り込み済み件数のサマリー、全削除ボタンまで含めて
/// 元の画面構成をそのまま再現している。
///
/// [PronunciationExerciseImportScreen]（レイヤーⅤ）と同じ動線を持つが、
/// お題は「見出し付きテキスト・3カテゴリ・全件クリア」という構造のため、
/// カテゴリごとの整合性検証やプレビューが必要な発音課題側とは
/// カード内側（サマリー・クリア操作）のみ別実装にしている。共通フローは
/// [AiImportFlowMixin]、パーサ・全削除は本画面。
class TopicImportScreen extends StatefulWidget {
  const TopicImportScreen({super.key});

  static Future<void> push(BuildContext context) {
    return pushAiImportScreen(context, const TopicImportScreen());
  }

  @override
  State<TopicImportScreen> createState() => _TopicImportScreenState();
}

class _TopicImportScreenState extends State<TopicImportScreen>
    with WidgetsBindingObserver, AiImportKeepAliveMixin, AiImportFlowMixin {
  final _service = TopicService();

  int _dailyCount = 0;
  int _businessCount = 0;
  int _situationalCount = 0;

  @override
  void initState() {
    super.initState();
    initAiImportFlow();
  }

  @override
  void dispose() {
    disposeAiImportFlow();
    super.dispose();
  }

  @override
  String get clipboardLoadedSuccessMessage =>
      'クリップボードから読み込みました。内容を確認して「お題を取り込む」を押してください。';

  @override
  bool looksLikeAiImport(String text) {
    return text.contains('【日常】') ||
        text.contains('【ビジネス】') ||
        text.contains('【シチュエーション】');
  }

  @override
  void onImportTextApplied(String text) {
    // お題はプレビュー解析なし。setState は applyImportText 側で済む。
  }

  @override
  Uri buildChromeAiUrl() => AIPromptTemplate.buildSearchUrl();

  @override
  Future<void> loadImportCounts() async {
    final daily = await _service.loadImported(TopicCategory.daily);
    final business = await _service.loadImported(TopicCategory.business);
    final situational = await _service.loadImported(TopicCategory.situational);
    if (!mounted) return;
    setState(() {
      _dailyCount = daily.length;
      _businessCount = business.length;
      _situationalCount = situational.length;
    });
  }

  Future<void> _import() async {
    final parsed = TopicImportParser.parseBatchImport(
      importTextController.text,
    );
    final dailyParsed = parsed[TopicCategory.daily] ?? const [];
    final businessParsed = parsed[TopicCategory.business] ?? const [];
    final situationalParsed = parsed[TopicCategory.situational] ?? const [];

    final dailyNew = await _service.importTopics(
      TopicCategory.daily,
      dailyParsed,
      source: QuestionPromptSource.ai,
    );
    final businessNew = await _service.importTopics(
      TopicCategory.business,
      businessParsed,
      source: QuestionPromptSource.ai,
    );
    final situationalNew = await _service.importTopics(
      TopicCategory.situational,
      situationalParsed,
      source: QuestionPromptSource.ai,
    );
    final total = dailyNew + businessNew + situationalNew;

    if (!mounted) return;

    if (total == 0) {
      final hasAnyParsed =
          dailyParsed.isNotEmpty ||
          businessParsed.isNotEmpty ||
          situationalParsed.isNotEmpty;
      setImportResult(
        message: hasAnyParsed
            ? '新しいお題はありませんでした（すべて重複しています）。'
            : 'お題を読み取れませんでした。【日常】【ビジネス】【シチュエーション】の見出し付きで貼り付けてください。',
        isError: true,
      );
      return;
    }

    importTextController.clear();
    await loadImportCounts();
    if (!mounted) return;
    setImportResult(
      message: '日常 %lld 件、ビジネス %lld 件、シチュエーション %lld 件を追加しました。',
      counts: [dailyNew, businessNew, situationalNew],
    );
  }

  Future<void> _clearAll() async {
    final lang = appSettings.language;
    final confirmed = await confirmAiImportClear(
      context: context,
      lang: lang,
      title: '取り込み済みお題をすべて削除'.tr(lang),
      body: '日常・ビジネス・シチュエーションすべての取り込み済みお題を削除します。この操作は取り消せません。'.tr(lang),
    );
    if (!confirmed) return;
    await _service.clearAllImported();
    await loadImportCounts();
    if (!mounted) return;
    setImportResult(message: '取り込み済みのお題をすべて削除しました。');
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        stopKeepAliveIfOwned();
      },
      child: SwipeToCloseWrapper(
        child: Material(
          color: palette.scene,
          child: SafeArea(
            child: Column(
              children: [
                AiImportHeader(title: 'お題の取り込み'.tr(lang), lang: lang),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      _buildQuickActionsCard(palette, lang),
                      const SizedBox(height: 16),
                      AiImportPromptCard(
                        lang: lang,
                        prompt: AIPromptTemplate.batchPrompt,
                      ),
                      const SizedBox(height: 16),
                      AiImportPasteCard(
                        lang: lang,
                        controller: importTextController,
                        onChanged: (_) => setState(() {}),
                        hintText: '【日常】\n1. ...',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsCard(AppPalette palette, String lang) {
    final canImport = importTextController.text.trim().isNotEmpty;
    final localizedResult = localizedResultMessage(lang);
    return AiImportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.upload_file,
                size: 20,
                color: palette.textOnCardPrimary,
              ),
              const SizedBox(width: 8),
              Text(
                'お題の取り込み'.tr(lang),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: palette.textOnCardPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Chrome AI で開く → 回答をコピー → 自動読み込み → 取り込む'.tr(lang),
            style: TextStyle(fontSize: 11, color: palette.textOnCardSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: QuickActionButton(
                  icon: openedAi ? Icons.check_circle : Icons.auto_awesome,
                  label: openedAi
                      ? 'Chrome AI を開きました'.tr(lang)
                      : 'Chrome AI で開く'.tr(lang),
                  onTap: openChromeAi,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: QuickActionButton(
                  icon: Icons.content_paste,
                  label: 'クリップボードから読み込む'.tr(lang),
                  onTap: canImport ? null : pasteFromClipboard,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: QuickActionButton(
                  icon: Icons.download_done,
                  label: '取り込む'.tr(lang),
                  onTap: canImport ? _import : null,
                  filled: true,
                ),
              ),
            ],
          ),
          if (localizedResult != null) ...[
            const SizedBox(height: 12),
            Text(
              localizedResult,
              style: TextStyle(
                fontSize: 12,
                color: resultIsError ? Colors.orange : Colors.green,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Divider(color: palette.cardBorder),
          const SizedBox(height: 8),
          Text(
            '取り込み済みのお題'.tr(lang),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: palette.textOnCardPrimary,
            ),
          ),
          const SizedBox(height: 8),
          AiImportCountRow(
            lang: lang,
            label: '日常'.tr(lang),
            count: _dailyCount,
          ),
          AiImportCountRow(
            lang: lang,
            label: 'ビジネス'.tr(lang),
            count: _businessCount,
          ),
          AiImportCountRow(
            lang: lang,
            label: 'シチュエーション'.tr(lang),
            count: _situationalCount,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _clearAll,
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label: Text(
              '全てクリア'.tr(lang),
              style: const TextStyle(color: Colors.red),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              side: const BorderSide(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
