import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/dashboard_ai_prompt_template.dart';
import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/dashboard_summary.dart';
import '../../models/saved_pronunciation_check.dart';
import '../../models/saved_scoring_result.dart';
import '../../models/saved_vocabulary_check.dart';
import '../../navigation/app_routes.dart';
import '../../services/chrome_ai_submit_mixin.dart';
import '../../services/dashboard_advice_storage.dart';
import '../../services/dashboard_summary_service.dart';
import '../../services/pronunciation_check_storage.dart';
import '../../services/scoring_result_storage.dart';
import '../../services/thinking_matrix_service.dart';
import '../../services/vocabulary_check_storage.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ai_import_shared.dart';
import '../../widgets/genki_transport_row.dart';
import '../../widgets/google_ai_send_consent_dialog.dart';
import '../../widgets/layer_numeral_badge.dart';
import '../../widgets/swipe_to_close_wrapper.dart';

/// スタート画面から開く総合ダッシュボード。
/// 直近3回のレイヤーⅣ・Ⅴ・Ⅰ結果から総合/JSST/的中度/PREP/語彙/発音を表示し、
/// 紙飛行機ボタンでChrome AIへ総合アドバイスを依頼→貼り付け保存する。
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  static Future<void> push(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const DashboardScreen()));
  }

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver, AiImportKeepAliveMixin, ChromeAiSubmitMixin {
  final _scoringStorage = ScoringResultStorage();
  final _pronunciationStorage = PronunciationCheckStorage();
  final _vocabularyStorage = VocabularyCheckStorage();
  final _adviceStorage = DashboardAdviceStorage();
  final _thinkingMatrixService = ThinkingMatrixService();

  DashboardSummary _summary = const DashboardSummary(
    overallGrade: DashboardOverallGrade.e,
    jsstSampleCount: 0,
    pronunciationSampleCount: 0,
    vocabularySampleCount: 0,
  );
  List<SavedScoringResult> _scoringResults = const [];
  List<SavedPronunciationCheck> _pronunciationChecks = const [];
  List<SavedVocabularyCheck> _vocabularyChecks = const [];
  String? _advice;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_reload());
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

  Future<void> _reload() async {
    // 25マス拡充度の母数65マス（日常/ビジネス/シチュエーション）を、
    // 未訪問でも読込前に確保する（Step 1）。
    await _thinkingMatrixService.ensureSystemPresets();
    final scoring = await _scoringStorage.loadAll();
    final pronunciation = await _pronunciationStorage.loadAll();
    final vocabulary = await _vocabularyStorage.loadAll();
    final thinkingMatrixSets = await _thinkingMatrixService.loadAll();
    final advice = await _adviceStorage.load();
    if (!mounted) return;
    setState(() {
      _scoringResults = scoring;
      _pronunciationChecks = pronunciation;
      _vocabularyChecks = vocabulary;
      _summary = DashboardSummaryService.build(
        scoringResults: scoring,
        pronunciationChecks: pronunciation,
        vocabularyChecks: vocabulary,
        thinkingMatrixSets: thinkingMatrixSets,
      );
      _advice = advice;
      _loading = false;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Future<bool> confirmChromeAiSend(String lang) {
    return GoogleAiSendConsentDialog.confirm(
      context,
      languageCode: lang,
      titleKey: 'ダッシュボード_Google送信確認_タイトル',
      bodyKey: 'ダッシュボード_Google送信確認_本文',
    );
  }

  @override
  void showChromeAiMessage(String message) => _showMessage(message);

  Future<void> _openScoringHistory() async {
    await AppRoutes.openScoringHistory(context);
    if (!mounted) return;
    await _reload();
  }

  Future<void> _openPronunciationHistory() async {
    await AppRoutes.openPronunciationHistory(context);
    if (!mounted) return;
    await _reload();
  }

  Future<void> _openVocabularyHistory() async {
    await AppRoutes.openVocabularyHistory(context);
    if (!mounted) return;
    await _reload();
  }

  /// 「テスト結果」各行タップ＝最新1件の詳細を開く（Step 8）。的中度・
  /// JSST・PREPの3行は同じ[ScoringResultStorage]なので同じ最新採点詳細を開く。
  Future<void> _openLatestScoringResult() async {
    await AppRoutes.openLatestScoringResult(context);
    if (!mounted) return;
    await _reload();
  }

  Future<void> _openLatestPronunciationCheck() async {
    await AppRoutes.openLatestPronunciationCheck(context);
    if (!mounted) return;
    await _reload();
  }

  Future<void> _openLatestVocabularyCheck() async {
    await AppRoutes.openLatestVocabularyCheck(context);
    if (!mounted) return;
    await _reload();
  }

  /// アドバイスを依頼する材料が1件でもあるか。総合判定（Step 9以降は
  /// 「5指標のうち1つでも欠ければE」なので、Eだからといって材料が
  /// 無いとは限らない）とは独立に、素材の有無だけで判定する。
  bool get _hasAnyData =>
      _scoringResults.isNotEmpty ||
      _pronunciationChecks.isNotEmpty ||
      _vocabularyChecks.isNotEmpty;

  /// [chromeAiSend]自体が[chromeAiActionInFlight]の二重タップ防止・
  /// トグルを内部で行うため、ここで同じフラグを事前に立てたり
  /// 早期returnで見たりはしない（やると[chromeAiSend]冒頭のガードに
  /// 引っかかって常に即returnし、何も起きなくなる）。
  Future<void> _sendToChromeAi() async {
    final lang = appSettings.language;
    final prompt = DashboardAiPromptTemplate.advicePrompt(
      scoringResults: _scoringResults,
      pronunciationChecks: _pronunciationChecks,
      vocabularyChecks: _vocabularyChecks,
      lang: lang,
      expansion: _summary.expansion,
      overallGrade: _summary.overallGrade,
    );
    final url = DashboardAiPromptTemplate.adviceSearchUrl(
      scoringResults: _scoringResults,
      pronunciationChecks: _pronunciationChecks,
      vocabularyChecks: _vocabularyChecks,
      lang: lang,
      expansion: _summary.expansion,
      overallGrade: _summary.overallGrade,
    );
    await chromeAiSend(lang: lang, prompt: prompt, url: url);
  }

  Future<void> _pasteAdvice() async {
    await runChromeAiPaste(() async {
      final lang = appSettings.language;
      final text = await readChromeAiPasteText();
      if (!mounted) return;
      if (text == null) {
        showChromeAiMessage('Chrome AIの解析結果を読み取れませんでした'.tr(lang));
        return;
      }
      if (chromeAiPasteLooksUnchanged(text, lang)) return;

      await _adviceStorage.save(text);
      if (!mounted) return;
      setState(() => _advice = text);
      clearChromeAiPendingState();
    });
  }

  Future<void> _onDiagnoseTap() =>
      chromeAiOnSubmitTap(onSend: _sendToChromeAi, onPaste: _pasteAdvice);

  /// アドバイス未取得時の案内文。材料が1件も無ければ紙飛行機を隠すため
  /// 挑戦を促し、1件でもあれば紙飛行機アイコン付きの案内を出す。
  /// 案内文中のアイコンは下のGenkiTransportRowの紙飛行機ボタンと見た目が
  /// 同じため、文中のアイコン自体もタップできるようにして、ユーザーが
  /// 案内どおりに文中のアイコンをタップしても反応するようにする。
  Widget _adviceEmptyContent(String lang, Color color, VoidCallback? onTap) {
    if (!_hasAnyData) {
      return Text(
        'ダッシュボード_アドバイス_挑戦'.tr(lang),
        style: TextStyle(fontSize: 15, height: 1.45, color: color),
      );
    }
    return _AdviceEmptyWithPlane(
      text: 'ダッシュボード_アドバイス空'.tr(lang),
      color: color,
      onTapPlane: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    // 材料が1件も無ければアドバイスのしようがないため飛行機を隠す。
    // 1件でもあれば紙飛行機で総合アドバイスを依頼できる（総合Eでも可）。
    final showDiagnose = _hasAnyData;
    final diagnoseEnabled = showDiagnose && !chromeAiActionInFlight;

    return SwipeToCloseWrapper(
      child: Scaffold(
        backgroundColor: palette.scene,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ダッシュボード'.tr(lang),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: palette.textOnScenePrimary,
                  ),
                ),
                const SizedBox(height: 16),
                if (_loading)
                  Expanded(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: palette.textOnScenePrimary,
                      ),
                    ),
                  )
                else ...[
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SectionCard(
                            title: '判定'.tr(lang),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _GradeJudgmentTable(
                                  lang: lang,
                                  overallLetter: _summary.overallGrade.letter,
                                  testLetter: _summary.testGrade.letter,
                                  testDetail: _summary.testGradeDetail,
                                  expansionLetter:
                                      _summary.expansionGrade.letter,
                                  expansionDetail:
                                      _summary.expansionGradeDetail,
                                ),
                                if (_summary.testGrade ==
                                    DashboardOverallGrade.e) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'ダッシュボード_E案内'.tr(lang),
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.4,
                                      color: palette.textOnCardSecondary,
                                    ),
                                  ),
                                ],
                                Divider(height: 24, color: palette.cardBorder),
                                _SectionHeading(text: 'テスト結果'.tr(lang)),
                                const SizedBox(height: 4),
                                _JudgmentRow(
                                  layerIndex: 0,
                                  label: '語彙'.tr(lang),
                                  value: _summary.vocabularyDisplayLabel,
                                  // タップ＝最新1件の詳細、長押し＝一覧（Step 8）。
                                  onTap: _openLatestVocabularyCheck,
                                  onLongPress: _openVocabularyHistory,
                                  trailingHint: true,
                                ),
                                _JudgmentRow(
                                  layerIndex: 1,
                                  label: '的中度'.tr(lang),
                                  value: _summary.hitDisplayLabel,
                                  onTap: _openLatestScoringResult,
                                  onLongPress: _openScoringHistory,
                                  trailingHint: true,
                                ),
                                _JudgmentRow(
                                  layerIndex: 2,
                                  label: 'PREP'.tr(lang),
                                  value: _summary.prepDisplayLabel,
                                  onTap: _openLatestScoringResult,
                                  onLongPress: _openScoringHistory,
                                  trailingHint: true,
                                ),
                                _JudgmentRow(
                                  layerIndex: 3,
                                  label: 'JSST'.tr(lang),
                                  value: _summary.jsstDisplayLabel,
                                  onTap: _openLatestScoringResult,
                                  onLongPress: _openScoringHistory,
                                  trailingHint: true,
                                ),
                                _JudgmentRow(
                                  layerIndex: 4,
                                  label: '発音'.tr(lang),
                                  value: _summary.pronunciationDisplayLabel,
                                  onTap: _openLatestPronunciationCheck,
                                  onLongPress: _openPronunciationHistory,
                                  trailingHint: true,
                                ),
                                Divider(height: 24, color: palette.cardBorder),
                                _SectionHeading(text: '25マス拡充度'.tr(lang)),
                                const SizedBox(height: 4),
                                _JudgmentRow(
                                  label: '日常'.tr(lang),
                                  value:
                                      _summary.expansion?.dailyDisplay ??
                                      '0.0%',
                                ),
                                _JudgmentRow(
                                  label: 'ビジネス'.tr(lang),
                                  value:
                                      _summary.expansion?.businessDisplay ??
                                      '0.0%',
                                ),
                                _JudgmentRow(
                                  label: 'シチュエーション'.tr(lang),
                                  value:
                                      _summary.expansion?.situationalDisplay ??
                                      '0.0%',
                                ),
                                _JudgmentRow(
                                  label: 'トータル'.tr(lang),
                                  value:
                                      _summary.expansion?.totalDisplay ??
                                      '0.0%',
                                  valueEmphasized: true,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _SectionCard(
                            title: 'アドバイス'.tr(lang),
                            child: chromeAiAwaitingPaste
                                ? Text(
                                    'Chromeから戻ったら貼り付けボタンを押して、アドバイスを保存しよう'.tr(
                                      lang,
                                    ),
                                    style: TextStyle(
                                      fontSize: 15,
                                      height: 1.45,
                                      color: palette.textOnCardPrimary,
                                    ),
                                  )
                                : (_advice?.isNotEmpty == true
                                      ? Text(
                                          _advice!,
                                          style: TextStyle(
                                            fontSize: 15,
                                            height: 1.45,
                                            color: palette.textOnCardPrimary,
                                          ),
                                        )
                                      : _adviceEmptyContent(
                                          lang,
                                          palette.textOnCardPrimary,
                                          diagnoseEnabled
                                              ? _onDiagnoseTap
                                              : null,
                                        )),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 材料が無ければ紙飛行機ボタン自体を出さないため、Play/Resetを
                  // 使わないこの画面ではGenkiTransportRowの予約枠（高さ56）ごと
                  // 省き、その分下の余白を詰める。
                  if (showDiagnose) ...[
                    const SizedBox(height: 12),
                    GenkiTransportRow(
                      showPlay: false,
                      showReset: false,
                      showDiagnose: true,
                      diagnoseHighlighted:
                          diagnoseEnabled && !chromeAiAwaitingPaste,
                      diagnoseAwaitingPaste: chromeAiAwaitingPaste,
                      onDiagnose: diagnoseEnabled ? _onDiagnoseTap : null,
                      languageCode: lang,
                      enableActionHints: true,
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// アドバイス空状態。[text]中の`{{plane}}`を紙飛行機アイコンに差し替える。
/// このアイコンは下のGenkiTransportRowの送信ボタンと見た目が同じなので、
/// [onTapPlane]を渡してここも実際にタップできるようにする
/// （nullなら送信不可の状態なのでタップしても反応しない）。
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

/// 「判定」カード内の小見出し（テスト結果／25マス拡充度）。カード自体の
/// タイトル（[_SectionCard.title]）より一段小さく、行の区切りを示す。
class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: palette.textOnCardSecondary,
      ),
    );
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

/// 判定3行（総合／テスト総合／拡充度総合）。A〜Eの文字を同じ横位置に揃え、
/// 括弧内の数値（3.5 / 50.0%）はその右に置く。
class _GradeJudgmentTable extends StatelessWidget {
  const _GradeJudgmentTable({
    required this.lang,
    required this.overallLetter,
    required this.testLetter,
    required this.testDetail,
    required this.expansionLetter,
    required this.expansionDetail,
  });

  final String lang;
  final String overallLetter;
  final String testLetter;
  final String testDetail;
  final String expansionLetter;
  final String expansionDetail;

  static const overallLetterKey = Key('dashboard-grade-letter-overall');
  static const testLetterKey = Key('dashboard-grade-letter-test');
  static const expansionLetterKey = Key('dashboard-grade-letter-expansion');

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final labelStyle = TextStyle(
      fontSize: 15,
      color: palette.textOnCardSecondary,
    );
    final letterStyle = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: palette.textOnCardPrimary,
      height: 1.1,
    );
    final overallLetterStyle = letterStyle.copyWith(
      fontWeight: FontWeight.w800,
    );
    final detailStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: palette.textOnCardPrimary,
      height: 1.1,
    );

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(),
        1: IntrinsicColumnWidth(),
        2: IntrinsicColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        _row(
          label: '総合'.tr(lang),
          letter: overallLetter,
          letterKey: overallLetterKey,
          letterStyle: overallLetterStyle,
          detail: '',
          labelStyle: labelStyle,
          detailStyle: detailStyle,
        ),
        _row(
          label: 'テスト総合'.tr(lang),
          letter: testLetter,
          letterKey: testLetterKey,
          letterStyle: letterStyle,
          detail: testDetail,
          labelStyle: labelStyle,
          detailStyle: detailStyle,
        ),
        _row(
          label: '拡充度総合'.tr(lang),
          letter: expansionLetter,
          letterKey: expansionLetterKey,
          letterStyle: letterStyle,
          detail: expansionDetail,
          labelStyle: labelStyle,
          detailStyle: detailStyle,
        ),
      ],
    );
  }

  static TableRow _row({
    required String label,
    required String letter,
    required Key letterKey,
    required TextStyle letterStyle,
    required String detail,
    required TextStyle labelStyle,
    required TextStyle detailStyle,
  }) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: labelStyle,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
          child: Text(letter, key: letterKey, style: letterStyle),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(detail, style: detailStyle),
        ),
      ],
    );
  }
}

class _JudgmentRow extends StatelessWidget {
  const _JudgmentRow({
    required this.label,
    required this.value,
    this.layerIndex,
    this.valueEmphasized = false,
    this.onTap,
    this.onLongPress,
    this.trailingHint = false,
  });

  final String label;
  final String value;

  /// 0=Ⅰ〜4=Ⅴ。非nullなら起動画面の[LayerListTile]と同じ「色付き丸＋
  /// ローマ数字」を行頭に出す（「総合」行はnullのまま、バッジ無し）。
  final int? layerIndex;

  final bool valueEmphasized;

  /// タップ＝最新1件の詳細を開く（Step 8）。
  final VoidCallback? onTap;

  /// 長押し＝結果一覧を開く（Step 8）。
  final VoidCallback? onLongPress;
  final bool trailingHint;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final layerIndex = this.layerIndex;
    // ラベルをExpandedにして残りの幅をすべて割り当てることで、英語・
    // ベトナム語の長いラベル（Overall/Relevance/Pronunciation等）でも
    // 折り返さないようにする。値は固定幅にせず自然な大きさのまま
    // 右側（行の末尾）に寄る（Rowはまず非flexな子＝値とchevronの必要幅を
    // 確保してから、残りをExpandedのラベルに割り当てるため）。
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (layerIndex != null) ...[
            LayerNumeralIcon(layerIndex: layerIndex, size: 28),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                color: palette.textOnCardSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: valueEmphasized ? 28 : 18,
              fontWeight: valueEmphasized ? FontWeight.w700 : FontWeight.w600,
              color: palette.textOnCardPrimary,
            ),
          ),
          if (trailingHint)
            Icon(
              Icons.chevron_right_rounded,
              color: palette.textOnCardSecondary,
            ),
        ],
      ),
    );
    if (onTap == null && onLongPress == null) return row;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(8),
      child: row,
    );
  }
}
