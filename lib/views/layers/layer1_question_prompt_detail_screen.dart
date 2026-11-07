import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/long_article_vocab_translation_prompt.dart';
import '../../data/question_prompt_vocab_extraction_ai_prompt_template.dart';
import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/question_prompt.dart';
import '../../models/vocabulary_entry.dart';
import '../../services/chrome_ai_submit_mixin.dart';
import '../../services/question_prompt_service.dart';
import '../../services/question_prompt_vocab_extraction_parser.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ai_import_shared.dart';
import '../../widgets/app_header.dart';
import '../../widgets/dice_action_row.dart';
import '../../widgets/google_ai_send_consent_dialog.dart';
import '../../widgets/layer_help_sheet.dart';
import '../../widgets/layer_numeral_badge.dart';
import '../../widgets/prep_label_row.dart';
import '../../widgets/question_prompt_nav_row.dart';
import '../../widgets/swipe_to_close_wrapper.dart';
import '../../widgets/tappable_japanese_text.dart';
import '../../widgets/transport_icon_button.dart';
import '../../widgets/vocabulary_sheet.dart';
import 'layer1_vocab_screen.dart';
import 'long_article_vocab_enrich_screen.dart';

/// レイヤーⅠ「問題文解析」の詳細画面（Step 2・Step 3）。
///
/// レイヤーⅡ〜Ⅳ（[DiceActionRow]／分野／本文／サイコロ／[PrepLabelRow]／
/// 下段3ボタン）と同じ「予約席」レイアウトを踏襲する（共通ルール1）。
/// このレイヤーではサイコロ抽選・分野切替を使わないため、該当スロットは
/// 枠だけ確保して隠す。「結論」枠は旧「理解」yes/noトグル（Step 1で完了判定
/// からは切り離し済み）を廃止し、「問題作成」（Step 2・Step 3）に差し替えた。
/// 未抽出（[QuestionPrompt.vocabTestWords]が空）のときのタップはChrome AIへ
/// 問題文を送り、学習者がつまずきやすい単語を最大5つ抽出して保存する
/// （[ChromeAiSubmitMixin]の送信/貼り付け単一ボタンパターンを、
/// [QuestionPromptSummaryScreen]と同じく別画面を経由せずこの詳細画面内で
/// 使う）。抽出済みのときのタップは、その単語で[Layer1VocabScreen]の語彙
/// テストを開始する（Step 3）。全問回答後の正解率・不正解語の単語帳自動
/// 登録は[Layer1VocabScreen._gradeQuestionPrompt]（`gradedPrompt`経由）に
/// 任せ、この画面はテストから戻ったときに最新状態を読み直すだけでよい。
/// 下段3ボタンは「訳付」「単語帳」
/// （[LongArticleReaderScreen]と同じ[TappableJapaneseText]・
/// [LongArticleVocabEnrichScreen]・[VocabularySheet]をそのまま流用）と
/// レイヤーⅡへの遷移ボタンに転用する。
///
/// 一覧から開いたときの表示順（[promptIds]）を保持し、「分野」枠に置いた
/// ▲▼ボタン（[QuestionPromptNavRow]）で前後の問題文へ画面を閉じずに移動
/// できる（▲＝前、▼＝次）。移動のたびに本文の内容が丸ごと変わるため、
/// [TappableJapaneseText]の内部状態（本文から作る不変のチャンク分割）が
/// 古い問題文のまま残らないよう、内容部分は[ValueKey]で毎回新規生成し直す
/// （[_Layer1PromptDetailBody]）。
class Layer1QuestionPromptDetailScreen extends StatefulWidget {
  const Layer1QuestionPromptDetailScreen({
    super.key,
    required this.promptIds,
    required this.initialIndex,
    this.onOpenPromptDetail,
    this.onSelectLayer,
    this.onGoToStart,
  });

  /// 一覧を開いたときのフィルタ条件での表示順（前後移動の対象範囲）。
  final List<String> promptIds;

  /// [promptIds]内での初期位置。
  final int initialIndex;

  /// 「II」タップ時に呼ぶ（[MainShellState.openPromptDetailInLayer]への参照。
  /// このウィジェット自身はレイヤー切り替えの仕組みを持たないため、
  /// [Layer1EntryScreen]経由で[MainShell]から渡してもらう）。
  final void Function(int layerIndex, String promptId)? onOpenPromptDetail;

  /// 画面上端の常設[AppHeader]「Ⅰ」〜「Ⅴ」タップ時に呼ぶ
  /// （[MainShellState.selectLayer]相当への参照。この画面自身を閉じてから
  /// 渡された番号のレイヤーへ切り替える）。
  final ValueChanged<int>? onSelectLayer;

  /// 画面上端の常設[AppHeader]のいずれかのボタン長押し時に呼ぶ
  /// （スタート画面へジャンプする導線。この画面自身を閉じてから呼ぶ）。
  final VoidCallback? onGoToStart;

  static Future<void> push(
    BuildContext context, {
    required List<String> promptIds,
    required int initialIndex,
    void Function(int layerIndex, String promptId)? onOpenPromptDetail,
    ValueChanged<int>? onSelectLayer,
    VoidCallback? onGoToStart,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Layer1QuestionPromptDetailScreen(
          promptIds: promptIds,
          initialIndex: initialIndex,
          onOpenPromptDetail: onOpenPromptDetail,
          onSelectLayer: onSelectLayer,
          onGoToStart: onGoToStart,
        ),
      ),
    );
  }

  @override
  State<Layer1QuestionPromptDetailScreen> createState() =>
      _Layer1QuestionPromptDetailScreenState();
}

class _Layer1QuestionPromptDetailScreenState
    extends State<Layer1QuestionPromptDetailScreen> {
  late int _index = widget.initialIndex;

  bool get _canGoPrevious => _index > 0;
  bool get _canGoNext => _index < widget.promptIds.length - 1;

  void _goPrevious() {
    if (!_canGoPrevious) return;
    setState(() => _index -= 1);
  }

  void _goNext() {
    if (!_canGoNext) return;
    setState(() => _index += 1);
  }

  void _handleHeaderSelect(int index) {
    Navigator.of(context).pop();
    widget.onSelectLayer?.call(index);
  }

  void _handleHeaderLongPress() {
    Navigator.of(context).pop();
    widget.onGoToStart?.call();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return SwipeToCloseWrapper(
      child: Scaffold(
        backgroundColor: palette.scene,
        appBar: AppHeader(
          currentIndex: 0,
          onSelect: _handleHeaderSelect,
          onLongPress: _handleHeaderLongPress,
        ),
        body: _Layer1PromptDetailBody(
          key: ValueKey(widget.promptIds[_index]),
          promptId: widget.promptIds[_index],
          onOpenPromptDetail: widget.onOpenPromptDetail,
          onSelectLayer: widget.onSelectLayer,
          onGoToStart: widget.onGoToStart,
          canGoPrevious: _canGoPrevious,
          canGoNext: _canGoNext,
          onGoPrevious: _goPrevious,
          onGoNext: _goNext,
        ),
      ),
    );
  }
}

class _Layer1PromptDetailBody extends StatefulWidget {
  const _Layer1PromptDetailBody({
    super.key,
    required this.promptId,
    this.onOpenPromptDetail,
    this.onSelectLayer,
    this.onGoToStart,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onGoPrevious,
    required this.onGoNext,
  });

  final String promptId;
  final void Function(int layerIndex, String promptId)? onOpenPromptDetail;

  /// [Layer1VocabScreen.push]へそのまま渡し、語彙テスト画面（Step 3）に
  /// 常設[AppHeader]を表示させる（この画面自身の[AppHeader]と同じ導線）。
  final ValueChanged<int>? onSelectLayer;
  final VoidCallback? onGoToStart;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onGoPrevious;
  final VoidCallback onGoNext;

  @override
  State<_Layer1PromptDetailBody> createState() =>
      _Layer1PromptDetailBodyState();
}

class _Layer1PromptDetailBodyState extends State<_Layer1PromptDetailBody>
    with WidgetsBindingObserver, AiImportKeepAliveMixin, ChromeAiSubmitMixin {
  final _service = QuestionPromptService();
  final _textKey = GlobalKey<TappableJapaneseTextState>();

  QuestionPrompt? _prompt;
  List<String> _registeredWordIds = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stopKeepAliveIfOwned();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      handleAppLifecycleState(state);

  @override
  void onResumedFromExternalApp() {
    if (!chromeAiAwaitingPaste) return;
    unawaited(_pasteVocabExtraction());
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void showChromeAiMessage(String message) => _showMessage(message);

  @override
  Future<bool> confirmChromeAiSend(String lang) {
    return GoogleAiSendConsentDialog.confirm(
      context,
      languageCode: lang,
      titleKey: 'レイヤーⅠ_問題作成_Google送信確認_タイトル',
      bodyKey: 'レイヤーⅠ_問題作成_Google送信確認_本文',
    );
  }

  Future<void> _load() async {
    final prompt = await _service.loadById(widget.promptId);
    if (!mounted) return;
    setState(() {
      _prompt = prompt;
      _registeredWordIds = List.of(prompt?.registeredWordIds ?? const []);
    });
  }

  Future<void> _persist(QuestionPrompt updated) async {
    setState(() => _prompt = updated);
    await _service.update(updated);
  }

  /// 「問題作成」タップ：貼り付け待ちならクリップボードを解析して保存する。
  /// そうでなく、既に単語を抽出済み（[QuestionPrompt.vocabTestWords]が
  /// 空でない）なら、その単語で語彙テストを開始する（Step 3）。未抽出なら
  /// Chrome AIへ送信する（Step 2）。
  Future<void> _onCreateQuizTap() async {
    if (chromeAiAwaitingPaste) {
      await _pasteVocabExtraction();
      return;
    }
    final prompt = _prompt;
    if (prompt != null && prompt.vocabTestWords.isNotEmpty) {
      await _openVocabTest(prompt);
      return;
    }
    await _sendVocabExtraction();
  }

  Future<void> _sendVocabExtraction() async {
    final prompt = _prompt;
    if (prompt == null) return;
    final lang = appSettings.language;
    final plan = QuestionPromptVocabExtractionAiPromptTemplate.buildLaunchPlan(
      prompt: prompt,
      appLanguage: lang,
    );
    await chromeAiSend(
      lang: lang,
      prompt: plan.prompt,
      url: plan.url,
      requiresClipboardPaste: plan.requiresClipboardPaste,
    );
  }

  Future<void> _pasteVocabExtraction() async {
    await runChromeAiPaste(() async {
      final lang = appSettings.language;
      final text = await consumeChromeAiPasteText(lang);
      if (text == null || !mounted) return;

      final result = QuestionPromptVocabExtractionParser.parse(text);
      final words = result.words;
      if (!result.isSuccess || words == null) {
        showChromeAiMessage('Chrome AIの回答を解析できませんでした'.tr(lang));
        return;
      }
      clearChromeAiPendingState();

      // 送信〜貼り付けの間に他レイヤー画面（IndexedStackで生きたまま）が
      // 同じ問題文を更新している可能性があるため、直前に最新状態を読み直して
      // からvocabTestWordsだけ上書きする（[QuestionPromptSummaryScreen]の
      // アドバイス保存と同じ考え方）。
      final current = await _service.loadById(widget.promptId);
      if (current == null || !mounted) return;
      await _persist(current.copyWith(vocabTestWords: words));
      showChromeAiMessage('レイヤーⅠ_問題作成_抽出件数'.trFmt(lang, ['${words.length}']));
    });
  }

  /// [prompt.vocabTestWords]（Step 2でChrome AIが抽出した単語）を仮の
  /// [VocabularyEntry]へ変換し、[Layer1VocabScreen.fixedEntries]として渡す
  /// （出題数＝抽出数、最大5）。単語帳へは登録せず、あくまで出題用の一時
  /// オブジェクト（IDは問題文IDから決定的に組み立てるだけで、単語帳側の
  /// エントリとは無関係）。訳語の言語は現在の表示言語から推定するため、
  /// Step 2の抽出時からアプリ言語を切り替えていた場合は一致しないことがある。
  List<VocabularyEntry> _vocabTestEntries(QuestionPrompt prompt) {
    final translationLang =
        LongArticleVocabTranslationPrompt.translationLangFor(
          appSettings.language,
        );
    return [
      for (var i = 0; i < prompt.vocabTestWords.length; i++)
        VocabularyEntry(
          id: 'qpvocab_${prompt.id}_$i',
          word: prompt.vocabTestWords[i].word,
          reading: prompt.vocabTestWords[i].reading,
          exampleSentence: prompt.vocabTestWords[i].example,
          translation: prompt.vocabTestWords[i].meaning,
          translationLang: translationLang,
          createdAt: prompt.createdAt,
        ),
    ];
  }

  /// Step 3: 抽出済みの単語で語彙テストを開始する。採点結果の問題文への
  /// 反映（正解率・不正解語の単語帳自動登録）は[Layer1VocabScreen]側
  /// （`gradedPrompt`）が行うため、戻ってきたらこの画面は最新状態を
  /// 読み直すだけでよい。
  Future<void> _openVocabTest(QuestionPrompt prompt) async {
    await Layer1VocabScreen.push(
      context,
      fixedEntries: _vocabTestEntries(prompt),
      sourcePromptId: prompt.id,
      sourcePromptBody: prompt.body,
      gradedPrompt: prompt,
      onSelectLayer: widget.onSelectLayer,
      onGoToStart: widget.onGoToStart,
    );
    await _load();
    await _textKey.currentState?.reloadRegisteredWords();
  }

  void _onWordRegistered(String id) {
    final prompt = _prompt;
    if (prompt == null) return;
    _registeredWordIds = [..._registeredWordIds, id];
    unawaited(_persist(prompt.copyWith(registeredWordIds: _registeredWordIds)));
  }

  void _onWordUnregistered(String id) {
    final prompt = _prompt;
    if (prompt == null) return;
    _registeredWordIds = _registeredWordIds.where((w) => w != id).toList();
    unawaited(_persist(prompt.copyWith(registeredWordIds: _registeredWordIds)));
  }

  Future<void> _openEnrich() async {
    await LongArticleVocabEnrichScreen.push(
      context,
      entryIds: List.of(_registeredWordIds),
    );
    await _textKey.currentState?.reloadRegisteredWords();
  }

  /// 長押し：選び直し画面を経由せず、確認なしで直接Chrome AIへ進む。
  Future<void> _openEnrichAutoSubmit() async {
    await LongArticleVocabEnrichScreen.push(
      context,
      entryIds: List.of(_registeredWordIds),
      autoSubmit: true,
    );
    await _textKey.currentState?.reloadRegisteredWords();
  }

  Future<void> _openVocabulary() async {
    await VocabularySheet.show(context);
    await _textKey.currentState?.reloadRegisteredWords();
  }

  void _showUsageHelp() {
    final lang = appSettings.language;
    LayerHelpSheet.show(
      context,
      title: '操作方法'.tr(lang),
      lines: [
        LayerHelpLine(text: 'レイヤーⅠ_問題文_使い方_問題作成'.tr(lang)),
        LayerHelpLine(text: 'レイヤーⅠ_問題文_使い方_単語登録'.tr(lang)),
        LayerHelpLine(text: 'レイヤーⅠ_問題文_使い方_訳付'.tr(lang)),
        LayerHelpLine(text: 'レイヤーⅠ_問題文_使い方_II'.tr(lang)),
      ],
    );
  }

  void _goToLayer2() {
    final prompt = _prompt;
    if (prompt == null) return;
    Navigator.of(context).pop();
    widget.onOpenPromptDetail?.call(1, prompt.id);
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    final prompt = _prompt;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: prompt == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DiceActionRow(
                    showAdd: true,
                    addIcon: Icons.add_rounded,
                    addTooltip: '操作方法',
                    // 既存の問題文を解析するモードのため、ここからの新規追加は
                    // 行わない（タップは無効。長押しの使い方シートのみ）。
                    onAddTap: () {},
                    onAddLongPress: _showUsageHelp,
                  ),
                  const SizedBox(height: 4),
                  // 分野は一覧のフィルタで絞り込めるため、詳細では表示せず、
                  // 同じ枠に前後の問題文へ移動する▲▼ボタンを置く。
                  QuestionPromptNavRow(
                    canGoPrevious: widget.canGoPrevious,
                    canGoNext: widget.canGoNext,
                    onPrevious: widget.onGoPrevious,
                    onNext: widget.onGoNext,
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: palette.cardFill,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: palette.cardBorder),
                        ),
                        child: TappableJapaneseText(
                          key: _textKey,
                          text: _displayText(prompt),
                          onWordRegistered: _onWordRegistered,
                          onWordUnregistered: _onWordUnregistered,
                          trackedEntryIds: _registeredWordIds,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // このレイヤーでは抽選（サイコロ）を使わないため、枠だけ
                  // 他レイヤーと揃えて確保し隠す。
                  const Visibility(
                    visible: false,
                    maintainState: true,
                    maintainAnimation: true,
                    maintainSize: true,
                    child: SizedBox(width: 196, height: 98),
                  ),
                  const SizedBox(height: 12),
                  PrepLabelRow(
                    showConclusion: true,
                    conclusionIcon: chromeAiAwaitingPaste
                        ? Icons.content_paste_go_rounded
                        : Icons.quiz_outlined,
                    // 「問題作成」は状況で3通りに役割が変わる（_onCreateQuizTap）：
                    // ①貼り付け待ち→貼り付け、②抽出済み→語彙テスト開始、
                    // ③未抽出→問題作成（Chrome AI抽出）。ツールチップ・
                    // ダブルタップヒントとも、この3状態を漏れなく反映すること
                    // （②を見落として「問題作成」のままにする不具合が実機で
                    // 見つかったため、両方をこの3分岐に統一した）。
                    conclusionTooltip: chromeAiAwaitingPaste
                        ? '貼り付け'
                        : (prompt.vocabTestWords.isNotEmpty ? '語彙テスト' : '問題作成'),
                    conclusionActive:
                        prompt.vocabTestWords.isNotEmpty || prompt.isLayer1Done,
                    onConclusionTap: chromeAiActionInFlight
                        ? null
                        : _onCreateQuizTap,
                    conclusionHintTapText: chromeAiAwaitingPaste
                        ? '貼り付け'
                        : (prompt.vocabTestWords.isNotEmpty ? '語彙テスト' : '問題作成'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TransportIconButton(
                          icon: Icons.translate_rounded,
                          tooltip: '訳を付ける'.tr(lang),
                          visible: _registeredWordIds.isNotEmpty,
                          onTap: _openEnrich,
                          onLongPress: _openEnrichAutoSubmit,
                          borderless: true,
                          hintTapText: '訳を付ける'.tr(lang),
                          hintLongPressText: 'ボタンヒント_訳付_長押し'.tr(lang),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TransportIconButton(
                          icon: Icons.style_rounded,
                          tooltip: '単語帳'.tr(lang),
                          visible: true,
                          onTap: _openVocabulary,
                          borderless: true,
                          hintTapText: '単語帳'.tr(lang),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LayerNumeralBadge(
                          layerIndex: 1,
                          onTap: _goToLayer2,
                          tooltip: 'レイヤーⅡタイトル'.tr(lang),
                          hintTapText: 'レイヤーⅡタイトル'.tr(lang),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  String _displayText(QuestionPrompt prompt) {
    final condition = prompt.situationCondition;
    if (condition == null || condition.isEmpty) return prompt.body;
    return '${prompt.body}\n\n$condition';
  }
}
