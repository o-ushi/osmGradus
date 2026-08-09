import 'package:flutter/material.dart';

import '../../data/pronunciation_exercise_ai_prompt.dart';
import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/pronunciation_exercise.dart';
import '../../services/pronunciation_exercise_import_parser.dart';
import '../../services/pronunciation_exercise_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ai_import_shared.dart';
import '../../widgets/swipe_to_close_wrapper.dart';

/// レイヤーⅤ「発音課題の取り込み」画面。[TopicImportScreen]（レイヤーⅡ）と
/// 同じ「Chrome AIで開く → 回答をコピー → 読み込む → 取り込む」動線を踏襲するが、
/// 発音課題はカテゴリ・対象音の整合性検証が必要な構造化データのため、
/// 取り込み前に解析結果を一覧プレビューする点が異なる。共通フローは
/// [AiImportFlowMixin]、パーサ・プレビュー・カテゴリ削除は本画面。
class PronunciationExerciseImportScreen extends StatefulWidget {
  const PronunciationExerciseImportScreen({super.key});

  static Future<void> push(BuildContext context) {
    return pushAiImportScreen(
      context,
      const PronunciationExerciseImportScreen(),
    );
  }

  @override
  State<PronunciationExerciseImportScreen> createState() =>
      _PronunciationExerciseImportScreenState();
}

class _PronunciationExerciseImportScreenState
    extends State<PronunciationExerciseImportScreen>
    with WidgetsBindingObserver, AiImportKeepAliveMixin, AiImportFlowMixin {
  final _service = const PronunciationExerciseService();

  PronunciationExerciseImportResult? _parseResult;

  Map<PronunciationCategory, int> _importedCounts = {
    for (final category in PronunciationCategory.values) category: 0,
  };

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
  bool looksLikeAiImport(String text) =>
      text.contains('"category"') && text.contains('"sentence"');

  @override
  void onImportTextApplied(String text) {
    _parseResult = text.trim().isEmpty
        ? null
        : PronunciationExerciseImportParser.parse(text);
  }

  @override
  Uri buildChromeAiUrl() => PronunciationExerciseAiPrompt.buildSearchUrl();

  @override
  Future<void> loadImportCounts() async {
    final counts = <PronunciationCategory, int>{};
    for (final category in PronunciationCategory.values) {
      counts[category] = (await _service.loadImported(category)).length;
    }
    if (!mounted) return;
    setState(() => _importedCounts = counts);
  }

  Future<void> _import() async {
    final parseResult = _parseResult;
    if (parseResult == null || parseResult.isEmpty) return;

    final addedCounts = await _service.importExercises(parseResult.exercises);
    final totalAdded = addedCounts.values.fold<int>(0, (a, b) => a + b);
    final totalDuplicates = parseResult.exercises.length - totalAdded;

    if (!mounted) return;

    if (totalAdded == 0) {
      setImportResult(
        message: '新しい発音課題はありませんでした（すべて重複しています）。',
        isError: true,
      );
      return;
    }

    importTextController.clear();
    setState(() => _parseResult = null);
    await loadImportCounts();
    if (!mounted) return;
    setImportResult(
      message: '%lld 件を追加しました（%lld 件は重複のため除外）',
      counts: [totalAdded, totalDuplicates],
    );
  }

  Future<void> _clearCategory(PronunciationCategory category) async {
    final lang = appSettings.language;
    final confirmed = await confirmAiImportClear(
      context: context,
      lang: lang,
      title: 'カテゴリ別の発音課題を削除'.tr(lang),
      body:
          '「%@」カテゴリの取り込み済み発音課題を削除します。組み込みの5問は削除されません。この操作は取り消せません。'
              .trFmt(lang, [category.label]),
    );
    if (!confirmed) return;
    await _service.clearImported(category);
    await loadImportCounts();
    if (!mounted) return;
    setImportResult(message: '取り込み済みの発音課題を削除しました');
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
                AiImportHeader(title: '発音課題の取り込み'.tr(lang), lang: lang),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      _buildQuickActionsCard(palette, lang),
                      const SizedBox(height: 16),
                      AiImportPromptCard(
                        lang: lang,
                        prompt: PronunciationExerciseAiPrompt.batchPrompt,
                      ),
                      const SizedBox(height: 16),
                      AiImportPasteCard(
                        lang: lang,
                        controller: importTextController,
                        onChanged: applyImportText,
                        hintText: '[{"category": "tsu", ...}, ...]',
                      ),
                      if (_parseResult != null) ...[
                        const SizedBox(height: 16),
                        _buildPreviewCard(palette, lang),
                      ],
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
    final hasText = importTextController.text.trim().isNotEmpty;
    final canImport = _parseResult != null && !_parseResult!.isEmpty;
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
                '発音課題の取り込み'.tr(lang),
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
                  onTap: hasText ? null : pasteFromClipboard,
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
            '取り込み済みの発音課題'.tr(lang),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: palette.textOnCardPrimary,
            ),
          ),
          const SizedBox(height: 8),
          for (final category in PronunciationCategory.values)
            AiImportCountRow(
              lang: lang,
              label: category.label,
              count: _importedCounts[category] ?? 0,
              onClear: () => _clearCategory(category),
              clearTooltip: 'カテゴリ別の発音課題を削除'.tr(lang),
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(AppPalette palette, String lang) {
    final result = _parseResult!;
    return AiImportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '取り込み候補のプレビュー'.tr(lang),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: palette.textOnCardPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            result.isEmpty
                ? '有効な発音課題を読み取れませんでした。JSON形式で出力されているか確認してください。'.tr(lang)
                : '%lld 件の候補が見つかりました（%lld 件は無効なため除外）'.trFmt(lang, [
                    result.exercises.length.toString(),
                    result.rejectedCount.toString(),
                  ]),
            style: TextStyle(
              fontSize: 12,
              color: result.isEmpty
                  ? Colors.orange
                  : palette.textOnCardSecondary,
            ),
          ),
          if (result.exercises.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final exercise in result.exercises)
              _ExercisePreviewTile(exercise: exercise, palette: palette),
          ],
        ],
      ),
    );
  }
}

class _ExercisePreviewTile extends StatelessWidget {
  const _ExercisePreviewTile({required this.exercise, required this.palette});

  final PronunciationExercise exercise;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.subpageBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            exercise.category.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: palette.textOnCardSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            exercise.sentence,
            style: TextStyle(fontSize: 14, color: palette.textOnCardPrimary),
          ),
          Text(
            exercise.reading,
            style: TextStyle(fontSize: 12, color: palette.textOnCardSecondary),
          ),
        ],
      ),
    );
  }
}
