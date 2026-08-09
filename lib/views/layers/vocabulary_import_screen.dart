import 'package:flutter/material.dart';

import '../../data/vocabulary_ai_import_prompt.dart';
import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/jlpt_vocab_word.dart';
import '../../models/vocabulary_level.dart';
import '../../services/jlpt_vocab_bank_service.dart';
import '../../services/vocabulary_import_parser.dart';
import '../../services/vocabulary_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ai_import_shared.dart';
import '../../widgets/level_checkbox_row.dart';
import '../../widgets/swipe_to_close_wrapper.dart';

/// レイヤーⅠ「語彙を増やす」の Chrome AI 語彙取り込み画面。
/// [TopicImportScreen] / [PronunciationExerciseImportScreen] と同じ
/// 「Chrome AIで開く → 回答をコピー → 読み込む → 取り込む」動線。
/// 取り込み先は既存の単語帳（[VocabularyService]）。
/// 共通フローは [AiImportFlowMixin]、パーサ・プレビュー・レベル削除は本画面。
class VocabularyImportScreen extends StatefulWidget {
  const VocabularyImportScreen({super.key});

  static Future<void> push(BuildContext context) {
    return pushAiImportScreen(context, const VocabularyImportScreen());
  }

  @override
  State<VocabularyImportScreen> createState() => _VocabularyImportScreenState();
}

class _VocabularyImportScreenState extends State<VocabularyImportScreen>
    with WidgetsBindingObserver, AiImportKeepAliveMixin, AiImportFlowMixin {
  final _bankService = JlptVocabBankService();
  final _vocabularyService = VocabularyService();

  VocabularyImportResult? _parseResult;

  Map<VocabularyLevel, int> _levelCounts = {
    VocabularyLevel.n1: 0,
    VocabularyLevel.n2: 0,
    VocabularyLevel.n3: 0,
  };

  static const _examLevels = [
    VocabularyLevel.n1,
    VocabularyLevel.n2,
    VocabularyLevel.n3,
  ];

  /// Chrome AIに生成させるレベル（チェックボックスで選択、既定は全レベル）。
  /// 空にはできない（[_toggleGenLevel]が最後の1つの解除を無視する）。
  final Set<VocabularyLevel> _selectedGenLevels = {
    VocabularyLevel.n1,
    VocabularyLevel.n2,
    VocabularyLevel.n3,
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
      text.contains('"level"') && text.contains('"word"');

  @override
  void onImportTextApplied(String text) {
    _parseResult = text.trim().isEmpty
        ? null
        : VocabularyImportParser.parse(text);
  }

  @override
  Uri buildChromeAiUrl() =>
      VocabularyAiImportPrompt.buildSearchUrl(_selectedGenLevels);

  @override
  Future<void> loadImportCounts() async {
    final counts = <VocabularyLevel, int>{};
    for (final level in _examLevels) {
      counts[level] = (await _vocabularyService.loadEntriesByLevel(
        level,
      )).length;
    }
    if (!mounted) return;
    setState(() => _levelCounts = counts);
  }

  /// 生成レベルのチェックボックス切り替え。最後の1つは解除できない
  /// （必ず1レベル以上を選んだ状態を保つ）。レベルが変わったら、古い
  /// プロンプトのまま開いた扱いにならないよう「開きました」表示を戻す。
  void _toggleGenLevel(VocabularyLevel level, bool checked) {
    setState(() {
      if (checked) {
        _selectedGenLevels.add(level);
      } else if (_selectedGenLevels.length > 1) {
        _selectedGenLevels.remove(level);
      }
      openedAi = false;
    });
  }

  Future<void> _import() async {
    final parseResult = _parseResult;
    if (parseResult == null || parseResult.isEmpty) return;

    final addedCounts = await _bankService.importWords(parseResult.words);
    final totalAdded = addedCounts.values.fold<int>(0, (a, b) => a + b);
    final totalDuplicates = parseResult.words.length - totalAdded;

    if (!mounted) return;

    if (totalAdded == 0) {
      setImportResult(
        message: '新しい語彙はありませんでした（すべて重複しています）。',
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

  Future<void> _clearLevel(VocabularyLevel level) async {
    final lang = appSettings.language;
    final confirmed = await confirmAiImportClear(
      context: context,
      lang: lang,
      title: 'レベル別の語彙を削除'.tr(lang),
      body: '「%@」の単語帳の語をすべて削除します。この操作は取り消せません。'.trFmt(lang, [
        _levelLabelKey(level).tr(lang),
      ]),
    );
    if (!confirmed) return;

    final entries = await _vocabularyService.loadEntriesByLevel(level);
    for (final entry in entries) {
      await _vocabularyService.deleteEntry(entry.id);
    }
    await loadImportCounts();
    if (!mounted) return;
    setImportResult(message: '単語帳の語を削除しました');
  }

  String _levelLabelKey(VocabularyLevel level) => switch (level) {
    VocabularyLevel.n1 => 'N1レベル',
    VocabularyLevel.n2 => 'N2レベル',
    VocabularyLevel.n3 => 'N3レベル',
    VocabularyLevel.other => '単語帳_レベルその他',
  };

  /// 生成レベルのチェックボックス用ラベル。"N1"はどの言語でも同じ表記の
  /// ため翻訳しない。
  String _levelShortName(VocabularyLevel level) => switch (level) {
    VocabularyLevel.n1 => 'N1',
    VocabularyLevel.n2 => 'N2',
    VocabularyLevel.n3 => 'N3',
    VocabularyLevel.other => '',
  };

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
                AiImportHeader(title: '語彙の取り込み'.tr(lang), lang: lang),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      _buildQuickActionsCard(palette, lang),
                      const SizedBox(height: 16),
                      AiImportPromptCard(
                        lang: lang,
                        prompt: VocabularyAiImportPrompt.buildBatchPrompt(
                          _selectedGenLevels,
                        ),
                      ),
                      const SizedBox(height: 16),
                      AiImportPasteCard(
                        lang: lang,
                        controller: importTextController,
                        onChanged: applyImportText,
                        hintText:
                            '[{"level": "n1", "word": "...", "reading": "...", '
                            '"exampleSentence": "...", '
                            '"translation": "...", "translationLang": "vi"}, ...]',
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
                '語彙の取り込み'.tr(lang),
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
          const SizedBox(height: 10),
          Text(
            '語彙取り込み_生成レベル'.tr(lang),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: palette.textOnCardSecondary,
            ),
          ),
          Row(
            children: [
              for (final level in _examLevels)
                Expanded(
                  child: LevelCheckboxRow(
                    label: _levelShortName(level),
                    checked: _selectedGenLevels.contains(level),
                    onChanged: (checked) => _toggleGenLevel(level, checked),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
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
            '単語帳の語彙'.tr(lang),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: palette.textOnCardPrimary,
            ),
          ),
          const SizedBox(height: 8),
          for (final level in _examLevels)
            AiImportCountRow(
              lang: lang,
              label: _levelLabelKey(level).tr(lang),
              count: _levelCounts[level] ?? 0,
              onClear: () => _clearLevel(level),
              clearTooltip: 'レベル別の語彙を削除'.tr(lang),
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
                ? '有効な語彙を読み取れませんでした。JSON形式で出力されているか確認してください。'.tr(lang)
                : '%lld 件の候補が見つかりました（%lld 件は無効なため除外）'.trFmt(lang, [
                    result.words.length.toString(),
                    result.rejectedCount.toString(),
                  ]),
            style: TextStyle(
              fontSize: 12,
              color: result.isEmpty
                  ? Colors.orange
                  : palette.textOnCardSecondary,
            ),
          ),
          if (result.words.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final word in result.words.take(30))
              _WordPreviewTile(
                word: word,
                levelLabel: _levelLabelKey(word.level).tr(lang),
                palette: palette,
              ),
            if (result.words.length > 30)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '…ほか %lld 件'.trFmt(lang, [
                    (result.words.length - 30).toString(),
                  ]),
                  style: TextStyle(
                    fontSize: 12,
                    color: palette.textOnCardSecondary,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _WordPreviewTile extends StatelessWidget {
  const _WordPreviewTile({
    required this.word,
    required this.levelLabel,
    required this.palette,
  });

  final JlptVocabWord word;
  final String levelLabel;
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
            levelLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: palette.textOnCardSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            word.word,
            style: TextStyle(fontSize: 14, color: palette.textOnCardPrimary),
          ),
          if (word.reading.isNotEmpty)
            Text(
              word.reading,
              style: TextStyle(
                fontSize: 12,
                color: palette.textOnCardSecondary,
              ),
            ),
          Text(
            word.translation,
            style: TextStyle(fontSize: 12, color: palette.textOnCardSecondary),
          ),
          if (word.exampleSentence.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                word.exampleSentence,
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: palette.textOnCardSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
