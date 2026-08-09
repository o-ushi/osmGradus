import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/prep_hit_ai_prompt_template.dart';
import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings, topicSpeechReader;
import '../../models/practice_timer_models.dart';
import '../../models/saved_scoring_result.dart';
import '../../services/alarm_sound_service.dart';
import '../../services/chrome_ai_submit_mixin.dart';
import '../../services/jsst_scoring_service.dart';
import '../../services/prep_hit_ai_response_parser.dart';
import '../../services/recording_stt_service.dart';
import '../../services/scoring_result_storage.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ai_import_shared.dart';
import '../../widgets/category_select_field.dart';
import '../../widgets/dice_action_row.dart';
import '../../widgets/dice_topic_card.dart';
import '../../widgets/genki_transport_row.dart';
import '../../widgets/layer_help_sheet.dart';
import '../../widgets/prep_label_row.dart';
import '../../widgets/topic_speaker_timer_button.dart';
import '../../widgets/transcribe_progress_indicator.dart';
import '../../widgets/last_recording_playback_mixin.dart';
import '../../widgets/reset_button_visibility_mixin.dart';
import '../topics/topic_add_flow.dart';
import 'practice_layer_screen.dart';
import 'scoring_history_screen.dart';

/// レイヤーⅣ：日本語での表現方法が分からない。
/// レイヤーⅢ（お題の読み上げ・osmGenki風の単一ボタンでのカウントダウン）を
/// ベースに、osmWashabeの録音・文字起こし・採点ロジックを組み合わせる。
/// レイヤーⅢと異なり、結論→理由→例示のPREPガイドは使わず（非表示）、
/// タイマーが0になったらそのまま採点を開始し、結果は「例示」枠の一覧から
/// 確認する（採点直後に詳細画面へ自動遷移はしない）。
/// 採点結果は件数上限なしでローカルに蓄積し、下段「例示」枠を流用した
/// 一覧ボタン（osmGenkiの日記画面の「閲覧」ボタンと同じ、結果があれば
/// 青地）から一覧・削除できる。「＋」タップはレイヤーⅡ・Ⅲと同じ
/// 「AIで追加/自分で追加」選択シートへの導線、長押しは操作方法シート。
/// お題・TTS・タイマー・録音開始タイミングの共通部分は[PracticeLayerScreenState]
/// （レイヤーⅢ・Ⅴと共有）に集約されている。
class Layer4Screen extends StatefulWidget {
  const Layer4Screen({super.key});

  @override
  State<Layer4Screen> createState() => Layer4ScreenState();
}

class Layer4ScreenState extends PracticeLayerScreenState<Layer4Screen>
    with
        WidgetsBindingObserver,
        AiImportKeepAliveMixin,
        ChromeAiSubmitMixin,
        ResetButtonVisibilityMixin,
        LastRecordingPlaybackMixin {
  final _storage = ScoringResultStorage();
  final _idRandom = Random();

  List<SavedScoringResult> _savedResults = [];
  bool _isEvaluating = false;
  double _transcribeProgress = 0;
  String _transcribePhase = '';
  StreamSubscription<TranscribeProgress>? _transcribeProgressSub;

  /// 直近にJSST採点・保存した結果（PREP・的中度の「送信」対象）。
  /// 新しいお題を引く／リセットすると解除する（Step 8）。
  SavedScoringResult? _lastResult;

  String _resetStateKey() => [
    buttonPhase.name,
    selectedCategory.name,
    timerController.option.name,
    drawnTopic?.text ?? '',
    recordingService.lastRecordingPath ?? '',
    _isEvaluating.toString(),
    (_lastResult?.hasAiEvaluation ?? false).toString(),
    chromeAiAwaitingPaste.toString(),
  ].join('|');

  bool get _showResetButton => showResetButton(_resetStateKey());

  /// PREP・的中度の「送信」ボタンを出すかどうか。JSST採点済み・
  /// まだAI評価が付いていないときだけtrue。
  bool get _showSendPrepHit =>
      _lastResult != null && !_lastResult!.hasAiEvaluation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedResults();
    initLastRecordingPlayback();
  }

  Future<void> _loadSavedResults() async {
    final results = await _storage.loadAll();
    if (!mounted) return;
    setState(() => _savedResults = results);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stopKeepAliveIfOwned();
    disposeLastRecordingPlayback();
    _transcribeProgressSub?.cancel();
    super.dispose();
  }

  @override
  void showChromeAiMessage(String message) => _showMessage(message);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      handleAppLifecycleState(state);

  @override
  void onResumedFromExternalApp() {
    if (!chromeAiAwaitingPaste) return;
    unawaited(_pasteAndSaveResult());
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void onTimerFinished() {
    unawaited(playAlarmThenReturnToIdle());
    unawaited(_evaluateNow());
  }

  /// 新しいお題を引くときは、直前の結果に対する「送信」ボタン・貼り付け待ちを
  /// 解除する（どの結果への送信か分からなくなるのを防ぐ）。
  @override
  Future<void> drawAndSpeak() async {
    setState(() {
      _lastResult = null;
      chromeAiAwaitingPaste = false;
      chromeAiPendingSentPrompt = null;
    });
    await super.drawAndSpeak();
  }

  /// 録音を停止・文字起こしして採点し、結果を保存する。
  /// 詳細は「例示」枠の一覧から開く。
  Future<void> _evaluateNow() async {
    if (_isEvaluating) return;
    setState(() {
      _isEvaluating = true;
      _transcribeProgress = 0;
      _transcribePhase = RecordingSttService.phaseAnalyzing;
    });
    // Android: 45〜60秒の長尺発話はVoskのみ（SpeechRecognizerはビープ・
    // タイムアウト・長尺非対応のため使わない）。進捗バーはVosk処理中に表示。
    _transcribeProgressSub = recordingService.transcribeProgressStream.listen((
      p,
    ) {
      if (!mounted) return;
      setState(() {
        _transcribeProgress = p.progress;
        _transcribePhase = p.phase;
      });
    });
    try {
      final chunks = await recordingService.stopAndTranscribe(
        skipOnlineRecognition: true,
      );
      final allottedSeconds = timerController.usesTwoPhaseTimer
          ? TimerPhase.speaking.durationSeconds
          : (timerController.option == NormalTimerOption.sec60 ? 60 : 45);
      final result = JsstScoringService.score(
        chunks,
        session: recordingService.sessionContext(
          allottedSeconds: allottedSeconds,
        ),
      );
      final now = DateTime.now();
      final saved = SavedScoringResult(
        id: '${now.microsecondsSinceEpoch}_${_idRandom.nextInt(1 << 32)}',
        createdAt: now,
        result: result,
      );
      await _storage.save(saved);
      if (!mounted) return;
      setState(() {
        _savedResults = [saved, ..._savedResults];
        _lastResult = saved;
        _isEvaluating = false;
      });
      final lang = appSettings.language;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('レイヤーⅣ_採点完了_案内'.tr(lang))));
    } catch (_) {
      if (mounted) setState(() => _isEvaluating = false);
    } finally {
      await _transcribeProgressSub?.cancel();
      _transcribeProgressSub = null;
    }
  }

  /// 「送信」：直近の採点結果（お題＋回答の文字起こし）からPREP・的中度を
  /// Chrome AIへ依頼する。JSST自体はローカル解析のみで完結するため、この
  /// 送信は任意（送らなくてもJSSTの結果は既に保存済み）。
  Future<void> _sendToChromeAi() async {
    final current = _lastResult;
    if (current == null || chromeAiAwaitingPaste || current.hasAiEvaluation) {
      return;
    }
    final lang = appSettings.language;
    final plan = PrepHitAiPromptTemplate.buildLaunchPlan(
      questionJa: drawnTopic?.text ?? '',
      answerTranscript: current.result.fullTranscript,
      lang: lang,
    );
    await chromeAiSend(
      lang: lang,
      prompt: plan.prompt,
      url: plan.url,
      requiresClipboardPaste: plan.requiresClipboardPaste,
    );
  }

  /// クリップボードのChrome AI回答を解析し、直近の採点結果へPREP・的中度を
  /// 書き足して保存し直す。解析に失敗した場合でも回答原文は
  /// [SavedScoringResult.aiEvaluationUnparsedResponse]として残す
  /// （レイヤーⅠ・Ⅴと同じ方針）。
  Future<void> _pasteAndSaveResult() async {
    await runChromeAiPaste(() async {
      final lang = appSettings.language;
      final text = await consumeChromeAiPasteText(lang);
      final current = _lastResult;
      if (!mounted || text == null || current == null) return;

      final parseResult = PrepHitAiResponseParser.parse(text);
      if (!parseResult.isSuccess) {
        showChromeAiMessage('Chrome AIの回答を解析できませんでした'.tr(lang));
        final updated = current.withAiEvaluation(
          aiEvaluationUnparsedResponse: text,
        );
        await _storage.update(updated);
        if (!mounted) return;
        _applyUpdatedResult(updated);
        clearChromeAiPendingState();
        return;
      }

      final eval = parseResult.evaluation!;
      final updated = current.withAiEvaluation(
        prepStars: eval.prepStars,
        hitStars: eval.hitStars,
        prepAdvice: eval.prepAdvice,
        hitAdvice: eval.hitAdvice,
      );
      await _storage.update(updated);
      if (!mounted) return;
      _applyUpdatedResult(updated);
      clearChromeAiPendingState();
    });
  }

  void _applyUpdatedResult(SavedScoringResult updated) {
    setState(() {
      _lastResult = updated;
      _savedResults = [
        for (final r in _savedResults)
          if (r.id == updated.id) updated else r,
      ];
    });
  }

  Future<void> _onSubmitPrepHitTap() => chromeAiOnSubmitTap(
    onSend: _sendToChromeAi,
    onPaste: _pasteAndSaveResult,
  );

  /// 「再生」ボタン：osmGenkiの「聴き直す」ボタンと同じ動線で、直近の録音を
  /// 再生⇄一時停止トグルする（採点結果自体には音声を保存しないため、
  /// あくまで直前の発話をその場で聴き直すだけの機能）。
  Future<void> _toggleLastRecordingPlayback() =>
      toggleLastRecordingPlayback(recordingService.lastRecordingPath);

  /// リセットボタン：読み上げ・アラーム・カウントダウンを即座に中止し、
  /// 初期状態（サイコロボタン）に戻す。
  @override
  Future<void> resetAttempt() async {
    unawaited(topicSpeechReader.stop());
    unawaited(AlarmSoundService.stop());
    await stopLastRecordingPlayback();
    await recordingService.cancel();
    // 録音データそのものを消去する。「再生」ボタンの青地表示
    // （playHasData）も、これでlastRecordingPathがnullに戻って消える。
    await recordingService.clearLastRecording();
    timerController.reset();
    prepStageController.reset();
    if (!mounted) return;
    setState(() {
      drawnTopic = null;
      buttonPhase = TopicSpeakerTimerPhase.idle;
      _lastResult = null;
      chromeAiAwaitingPaste = false;
      chromeAiPendingResponseLanguage = 'ja';
      chromeAiPendingSentPrompt = null;
      hideResetUntilNextChange(_resetStateKey());
    });
  }

  Future<void> _openHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ScoringHistoryScreen()),
    );
    // 一覧画面で削除された可能性があるため、戻ってきたら再読み込みする。
    await _loadSavedResults();
  }

  Future<void> _showAddChoice() =>
      showTopicAddChoiceFlow(context, initialCategory: selectedCategory);

  /// 「＋」長押し：タイマー〜採点結果確認までのステップを表示する。
  void _showUsageHelp() {
    final lang = appSettings.language;
    LayerHelpSheet.show(
      context,
      title: '操作方法'.tr(lang),
      lines: [
        LayerHelpLine(text: 'レイヤーⅣ_使い方_タイマー'.tr(lang)),
        LayerHelpLine(text: 'レイヤーⅣ_使い方_分野'.tr(lang)),
        LayerHelpLine(text: 'レイヤーⅣ_使い方_サイコロ'.tr(lang), icon: Icons.casino),
        LayerHelpLine(text: 'レイヤーⅣ_使い方_日本語回答'.tr(lang)),
        LayerHelpLine(
          text: 'レイヤーⅣ_使い方_PREP的中度'.tr(lang),
          icon: Icons.send_rounded,
        ),
        LayerHelpLine(text: 'レイヤーⅣ_使い方_採点結果'.tr(lang)),
      ],
    );
  }

  // ── テスト専用フック ──────────────────────────────────────────────────
  // 実機のネイティブ録音・文字起こしは Flutter widget test 上で再現できない
  // ため、[Layer5ScreenState]と同じく、JSST採点直後の状態（[_lastResult]）
  // を経由せず直接与えるフックのみを用意する。

  @visibleForTesting
  SavedScoringResult? get debugLastResult => _lastResult;

  /// 実際のタイマー終了・録音・文字起こしを経由せず、JSST採点済みの結果を
  /// 直接与える（[_sendToChromeAi]・[_pasteAndSaveResult]のテスト用）。
  @visibleForTesting
  void debugSetEvaluatedResult(SavedScoringResult result) {
    setState(() {
      _savedResults = [result, ..._savedResults];
      _lastResult = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    return Container(
      color: palette.scene,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListenableBuilder(
                listenable: timerController,
                builder: (context, _) => DiceActionRow(
                  show45: true,
                  show60: true,
                  show15Plus60: true,
                  showAdd: true,
                  addIcon: Icons.add_rounded,
                  addTooltip: 'お題の取り込み',
                  selectedOption: timerController.option,
                  onPresetTap: onPresetTap,
                  onAddTap: _showAddChoice,
                  onAddLongPress: _showUsageHelp,
                ),
              ),
              const SizedBox(height: 4),
              ListenableBuilder(
                listenable: timerController,
                builder: (context, _) => CategorySelectField(
                  selected: selectedCategory,
                  availableCategories: availableCategories,
                  onChanged: onCategoryChanged,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DiceTopicCard(topic: drawnTopic),
                      const SizedBox(height: 8),
                      Text(
                        '日本語で回答しよう'.tr(lang),
                        style: TextStyle(
                          fontSize: 13,
                          color: palette.textOnSceneSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: ListenableBuilder(
                  listenable: Listenable.merge([
                    timerController,
                    topicSpeechReader,
                  ]),
                  builder: (context, _) => TopicSpeakerTimerButton(
                    phase: buttonPhase,
                    remainingSeconds: timerController.remainingSeconds,
                    isPaused: topicSpeechReader.isPaused,
                    onTap: onButtonTap,
                    size: 98,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // レイヤーⅢと異なり、PREPガイドは使わないため「結論」「理由」は
              // 非表示のまま、「例示」の枠だけ「＋」と同じ結果一覧導線に転用する。
              // 保存済み採点結果があるときだけ表示する。
              PrepLabelRow(
                showExample: _savedResults.isNotEmpty,
                exampleIcon: Icons.list_alt_rounded,
                exampleTooltip: '採点結果',
                exampleActive: _savedResults.isNotEmpty,
                onExampleTap: _openHistory,
              ),
              const SizedBox(height: 8),
              Stack(
                alignment: Alignment.center,
                children: [
                  ListenableBuilder(
                    listenable: timerController,
                    builder: (context, _) => GenkiTransportRow(
                      showPlay: true,
                      showReset: _showResetButton,
                      showDiagnose: _showSendPrepHit || chromeAiAwaitingPaste,
                      languageCode: lang,
                      playing: isPlayingLastRecording,
                      playHasData: recordingService.lastRecordingPath != null,
                      diagnoseHighlighted:
                          _showSendPrepHit && !chromeAiAwaitingPaste,
                      diagnoseAwaitingPaste: chromeAiAwaitingPaste,
                      onPlay: _toggleLastRecordingPlayback,
                      onReset: resetAttempt,
                      onDiagnose:
                          !chromeAiActionInFlight &&
                              (_showSendPrepHit || chromeAiAwaitingPaste)
                          ? _onSubmitPrepHitTap
                          : null,
                    ),
                  ),
                  // 文字起こし中は、レイアウトの高さを変えずに「再生」
                  // 「リセット」ボタンの上へ進捗をそのまま重ねて表示する
                  // （下に別枠を足すとボタン列が上にずれてしまうため）。
                  if (_isEvaluating)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: palette.scene,
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Center(
                            child: TranscribeProgressIndicator(
                              progress: _transcribeProgress,
                              phase: _transcribePhase,
                              compact: true,
                              active: _isEvaluating,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
