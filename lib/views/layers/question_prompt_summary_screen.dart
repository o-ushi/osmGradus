import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/jsst_reference_samples.dart';
import '../../data/question_prompt_summary_ai_prompt_template.dart';
import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/pronunciation_exercise.dart';
import '../../models/question_prompt.dart';
import '../../models/vocabulary_entry.dart';
import '../../services/chrome_ai_submit_mixin.dart';
import '../../services/question_prompt_service.dart';
import '../../services/vocabulary_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ai_import_shared.dart';
import '../../widgets/genki_transport_row.dart';
import '../../widgets/google_ai_send_consent_dialog.dart';
import '../../widgets/layer_numeral_badge.dart';
import '../../widgets/question_prompt_summary_score_header.dart';
import '../../widgets/swipe_to_close_wrapper.dart';

/// 1問題文についてレイヤーⅠ〜Ⅴを横断した結果を見せる総評画面（Step 7）。
///
/// [DashboardScreen]の「送信 → Chrome AI → 貼り付け保存」の往復をそのまま
/// 踏襲するが、対象は直近の練習履歴の集計ではなく「1つの問題文」に絞る。
/// アドバイスは[QuestionPrompt.advice]に保存し、次回開いたときも再表示する。
///
/// レイヤーⅠの語彙テストは、Step 4以降ここからは起動できない
/// （[Layer1QuestionPromptDetailScreen]の「問題作成」で完結する、Step 3）。
/// ここでは[QuestionPrompt.vocabTestAccuracy]をタップ不可のテキストで
/// 淡々と表示するだけにとどめる。
class QuestionPromptSummaryScreen extends StatefulWidget {
  const QuestionPromptSummaryScreen({super.key, required this.promptId});

  final String promptId;

  static Future<void> push(BuildContext context, {required String promptId}) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuestionPromptSummaryScreen(promptId: promptId),
      ),
    );
  }

  @override
  State<QuestionPromptSummaryScreen> createState() =>
      _QuestionPromptSummaryScreenState();
}

class _QuestionPromptSummaryScreenState
    extends State<QuestionPromptSummaryScreen>
    with WidgetsBindingObserver, AiImportKeepAliveMixin, ChromeAiSubmitMixin {
  final _service = QuestionPromptService();
  final _vocabularyService = VocabularyService();

  QuestionPrompt? _prompt;
  List<VocabularyEntry> _registeredWords = const [];
  bool _loading = true;

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
    unawaited(_pasteAdvice());
  }

  Future<void> _load() async {
    final prompt = await _service.loadById(widget.promptId);
    final entries = prompt == null
        ? const <VocabularyEntry>[]
        : await _vocabularyService.loadEntries();
    if (!mounted) return;
    setState(() {
      _prompt = prompt;
      _registeredWords = prompt == null
          ? const []
          : entries
                .where((e) => prompt.registeredWordIds.contains(e.id))
                .toList();
      _loading = false;
    });
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
      titleKey: '総評_Google送信確認_タイトル',
      bodyKey: '総評_Google送信確認_本文',
    );
  }

  /// 材料（登録単語・要約・PREP・各種スコア）が1件でもあるか。
  /// 何も無い問題文をAIへ送っても得るものが無いため、紙飛行機を隠す判断に使う。
  bool get _hasAnyData {
    final prompt = _prompt;
    if (prompt == null) return false;
    return _registeredWords.isNotEmpty ||
        prompt.summary.isNotEmpty ||
        prompt.isPrepFilled ||
        prompt.jsstScore != null ||
        prompt.hitScore != null ||
        prompt.prepScore != null ||
        prompt.hasPronunciationScore;
  }

  Future<void> _sendToChromeAi() async {
    final prompt = _prompt;
    if (prompt == null) return;
    final lang = appSettings.language;
    final plan = QuestionPromptSummaryAiPromptTemplate.buildLaunchPlan(
      prompt: prompt,
      registeredWords: [for (final w in _registeredWords) w.word],
      lang: lang,
    );
    await chromeAiSend(
      lang: lang,
      prompt: plan.prompt,
      url: plan.url,
      requiresClipboardPaste: plan.requiresClipboardPaste,
    );
  }

  Future<void> _pasteAdvice() async {
    await runChromeAiPaste(() async {
      final lang = appSettings.language;
      final text = await consumeChromeAiPasteText(lang);
      if (text == null || !mounted) return;
      if (_prompt == null) return;
      // 送信〜Chromeでの操作〜貼り付けの間に、他のレイヤー画面（Ⅰ〜Ⅴの
      // 各詳細画面はMainShellのIndexedStackで生かしたまま保持される）で
      // 単語登録・理解フラグ・スコア等が更新されている可能性があるため、
      // 初回読み込み時の[_prompt]をそのまま土台にすると、保存時にそれらの
      // 変更を消してしまう（Layer4Screen._persistScoreToPrompt等、他の
      // 「1件だけ書き足す」保存と同じく、直前に最新状態を読み直してから
      // アドバイスだけ上書きする）。
      final current = await _service.loadById(widget.promptId);
      if (current == null || !mounted) return;
      final updated = current.copyWith(advice: text);
      await _service.update(updated);
      if (!mounted) return;
      setState(() => _prompt = updated);
      clearChromeAiPendingState();
    });
  }

  Future<void> _onDiagnoseTap() =>
      chromeAiOnSubmitTap(onSend: _sendToChromeAi, onPaste: _pasteAdvice);

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    final prompt = _prompt;

    return SwipeToCloseWrapper(
      child: Scaffold(
        backgroundColor: palette.scene,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                      color: palette.textOnScenePrimary,
                    ),
                  )
                : prompt == null
                ? _NotFoundContent(lang: lang)
                : _buildContent(context, lang, palette, prompt),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    String lang,
    AppPalette palette,
    QuestionPrompt prompt,
  ) {
    final showDiagnose = _hasAnyData;
    final diagnoseEnabled = showDiagnose && !chromeAiActionInFlight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '総評'.tr(lang),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: palette.textOnScenePrimary,
          ),
        ),
        const SizedBox(height: 12),
        QuestionPromptSummaryScoreHeader(prompt: prompt),
        const SizedBox(height: 12),
        Text(
          prompt.body,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, color: palette.textOnSceneSecondary),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LayerSectionCard(
                  layerIndex: 0,
                  title: 'レイヤーⅠタイトル'.tr(lang),
                  children: [
                    _FieldRow(
                      label: '分からなかった単語'.tr(lang),
                      value: _registeredWords.isEmpty
                          ? 'ー'
                          : _registeredWords.map((w) => w.word).join('、'),
                    ),
                    // 語彙テストはStep 3でレイヤーⅠの「問題作成」内に完結して
                    // おり、ここからは起動しない（タップ不可、正解率のみ表示）。
                    _FieldRow(
                      label: '正解率'.tr(lang),
                      value: prompt.vocabTestAccuracy == null
                          ? 'ー'
                          : '${(prompt.vocabTestAccuracy! * 100).round()}%',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _LayerSectionCard(
                  layerIndex: 1,
                  title: 'レイヤーⅡタイトル'.tr(lang),
                  children: [
                    _FieldRow(
                      label: '回答の要約'.tr(lang),
                      value: prompt.summary.isEmpty ? 'ー' : prompt.summary,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _LayerSectionCard(
                  layerIndex: 2,
                  title: 'レイヤーⅢタイトル'.tr(lang),
                  children: [
                    _FieldRow(
                      label: '結論'.tr(lang),
                      value: prompt.conclusion.isEmpty
                          ? 'ー'
                          : prompt.conclusion,
                    ),
                    _FieldRow(
                      label: '理由'.tr(lang),
                      value: prompt.reason.isEmpty ? 'ー' : prompt.reason,
                    ),
                    _FieldRow(
                      label: '例示'.tr(lang),
                      value: prompt.example.isEmpty ? 'ー' : prompt.example,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _LayerSectionCard(
                  layerIndex: 3,
                  title: 'レイヤーⅣタイトル'.tr(lang),
                  children: [
                    _FieldRow(
                      label: 'JSST'.tr(lang),
                      value: prompt.jsstScore == null
                          ? 'ー'
                          : JsstReferenceSamples.levelLabel(prompt.jsstScore),
                    ),
                    _FieldRow(
                      label: '的中度'.tr(lang),
                      value: prompt.hitScore?.toString() ?? 'ー',
                    ),
                    _FieldRow(
                      label: 'PREP'.tr(lang),
                      value: prompt.prepScore?.toString() ?? 'ー',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _LayerSectionCard(
                  layerIndex: 4,
                  title: 'レイヤーⅤタイトル'.tr(lang),
                  children: [
                    for (final category in PronunciationCategory.values)
                      _FieldRow(
                        label: category.label,
                        value:
                            prompt.pronunciationScores[category]?.toString() ??
                            'ー',
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'アドバイス'.tr(lang),
                  child: chromeAiAwaitingPaste
                      ? Text(
                          'Chromeから戻ったら貼り付けボタンを押して、アドバイスを保存しよう'.tr(lang),
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.45,
                            color: palette.textOnCardPrimary,
                          ),
                        )
                      : (prompt.advice.isNotEmpty
                            ? Text(
                                prompt.advice,
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.45,
                                  color: palette.textOnCardPrimary,
                                ),
                              )
                            : _adviceEmptyContent(
                                lang,
                                palette.textOnCardPrimary,
                                diagnoseEnabled ? _onDiagnoseTap : null,
                              )),
                ),
              ],
            ),
          ),
        ),
        if (showDiagnose) ...[
          const SizedBox(height: 12),
          GenkiTransportRow(
            showPlay: false,
            showReset: false,
            showDiagnose: true,
            diagnoseHighlighted: diagnoseEnabled && !chromeAiAwaitingPaste,
            diagnoseAwaitingPaste: chromeAiAwaitingPaste,
            onDiagnose: diagnoseEnabled ? _onDiagnoseTap : null,
            languageCode: lang,
            enableActionHints: true,
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _adviceEmptyContent(String lang, Color color, VoidCallback? onTap) {
    if (!_hasAnyData) {
      return Text(
        '総評_アドバイス_挑戦'.tr(lang),
        style: TextStyle(fontSize: 15, height: 1.45, color: color),
      );
    }
    return _AdviceEmptyWithPlane(
      text: 'ダッシュボード_アドバイス空'.tr(lang),
      color: color,
      onTapPlane: onTap,
    );
  }
}

class _NotFoundContent extends StatelessWidget {
  const _NotFoundContent({required this.lang});

  final String lang;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return Center(
      child: Text(
        '問題文が見つかりません'.tr(lang),
        style: TextStyle(fontSize: 15, color: palette.textOnScenePrimary),
      ),
    );
  }
}

/// アドバイス空状態。[text]中の`{{plane}}`を紙飛行機アイコンに差し替える
/// （[DashboardScreen]の同名ウィジェットと同じ挙動）。
class _AdviceEmptyWithPlane extends StatelessWidget {
  const _AdviceEmptyWithPlane({
    required this.text,
    required this.color,
    this.onTapPlane,
  });

  final String text;
  final Color color;
  final VoidCallback? onTapPlane;

  static final RegExp _token = RegExp(r'\{\{plane\}\}');

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 15, height: 1.45, color: color);
    final spans = <InlineSpan>[];
    var start = 0;
    for (final match in _token.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: GestureDetector(
            onTap: onTapPlane,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Icon(Icons.send_rounded, size: 18, color: color),
            ),
          ),
        ),
      );
      start = match.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }
    return Text.rich(TextSpan(style: style, children: spans));
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: palette.textOnCardPrimary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// レイヤーごとの結果カード。起動画面と同じ「色付き丸＋ローマ数字」を
/// タイトル行の先頭に置く（共通ルール3）。表示専用のため[LayerNumeralIcon]を使う。
class _LayerSectionCard extends StatelessWidget {
  const _LayerSectionCard({
    required this.layerIndex,
    required this.title,
    required this.children,
  });

  final int layerIndex;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LayerNumeralIcon(layerIndex: layerIndex, size: 26),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: palette.textOnCardPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

/// ラベル（小さいキャプション）＋値の2行スタック。単語一覧のような短い
/// ラベルから結論・理由の長文まで、幅を固定せず自然に折り返す。
class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: palette.textOnCardSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: palette.textOnCardPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
