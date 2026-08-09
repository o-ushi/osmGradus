import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/long_reading_ai_prompt_template.dart';
import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings, topicSpeechReader;
import '../../models/long_article.dart';
import '../../models/pronunciation_evaluation.dart';
import '../../models/saved_pronunciation_check.dart';
import '../../services/chrome_ai_submit_mixin.dart';
import '../../services/pronunciation_ai_response_parser.dart';
import '../../services/pronunciation_check_storage.dart';
import '../../services/recording_stt_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ai_import_shared.dart';
import '../../widgets/genki_transport_row.dart';
import '../../widgets/google_ai_send_consent_dialog.dart';
import '../../widgets/last_recording_playback_mixin.dart';
import '../../widgets/prep_label_row.dart';
import '../../widgets/pronunciation_evaluation_result_view.dart';
import '../../widgets/pronunciation_mic_button.dart';
import '../../widgets/reset_button_visibility_mixin.dart';
import '../../widgets/speech_processing_consent_dialog.dart';
import '../../widgets/transcribe_progress_indicator.dart';
import 'pronunciation_history_screen.dart';

/// レイヤーⅤ「長文」：長文一覧からランダムに選んだ[article]を音読し、
/// 端末STT→Chrome AIで参考評価を受け取る（osmCogitoの
/// `CogitoLongReadingScreen`の移植）。
///
/// 短文10問（[Layer5Screen]）と違い出題は1本の長文のみなので、サイコロ→
/// マイクの2段階ではなく、画面を開いた時点で本文を全文表示し、マイクボタンは
/// 常に「録音の構え」（[PronunciationMicButton.armed] = true）から始まる。
///
/// 録音は最短15秒（赤・タップ無効）→15秒経過後はオレンジに変わりタップで
/// 停止可能→3分で自動停止する（osmCogitoと同じ`_pastMinRecording`の考え方）。
/// 15秒未満で止められないのは、あまりに短い音読では発音評価の材料として
/// 不十分なため。
class Layer5LongReadingScreen extends StatefulWidget {
  const Layer5LongReadingScreen({super.key, required this.article});

  final LongArticle article;

  @override
  State<Layer5LongReadingScreen> createState() =>
      Layer5LongReadingScreenState();
}

class Layer5LongReadingScreenState extends State<Layer5LongReadingScreen>
    with
        WidgetsBindingObserver,
        AiImportKeepAliveMixin,
        ChromeAiSubmitMixin,
        ResetButtonVisibilityMixin,
        LastRecordingPlaybackMixin {
  static const minRecordingDuration = Duration(seconds: 15);
  static const _maxRecordingDuration = Duration(minutes: 3);

  final _recordingService = RecordingSttService();
  final _storage = PronunciationCheckStorage();
  final _idRandom = Random();

  late String _sessionId;

  bool _recording = false;
  bool _pastMinRecording = false;
  bool _isTranscribing = false;
  bool _isSaved = false;
  bool _hasSavedChecks = false;
  String? _transcript;
  double _transcribeProgress = 0;
  String _transcribePhase = '';
  StreamSubscription<TranscribeProgress>? _transcribeProgressSub;
  Timer? _minRecordingTimer;
  Timer? _autoStopTimer;

  bool get _canRecord =>
      !chromeAiActionInFlight && !chromeAiAwaitingPaste && !_isTranscribing;

  String _resetStateKey() => [
    _recording.toString(),
    _transcript ?? '',
    chromeAiAwaitingPaste.toString(),
    _isSaved.toString(),
    _recordingService.lastRecordingPath ?? '',
  ].join('|');

  bool get _showResetButton => showResetButton(_resetStateKey());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionId = _newSessionId();
    initLastRecordingPlayback();
    unawaited(_loadHasSavedChecks());
  }

  String _newSessionId() =>
      'longsess_${DateTime.now().microsecondsSinceEpoch}_${_idRandom.nextInt(1 << 32)}';

  Future<void> _loadHasSavedChecks() async {
    final checks = await _storage.loadAll();
    if (!mounted) return;
    setState(() => _hasSavedChecks = checks.isNotEmpty);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stopKeepAliveIfOwned();
    disposeLastRecordingPlayback();
    _transcribeProgressSub?.cancel();
    _minRecordingTimer?.cancel();
    _autoStopTimer?.cancel();
    _recordingService.dispose();
    super.dispose();
  }

  @override
  void showChromeAiMessage(String message) => _showMessage(message);

  @override
  Future<bool> confirmChromeAiSend(String lang) {
    return GoogleAiSendConsentDialog.confirm(
      context,
      languageCode: lang,
      titleKey: 'レイヤーⅤ_長文_Google送信確認_タイトル',
      bodyKey: 'レイヤーⅤ_長文_Google送信確認_本文',
    );
  }

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

  void _listenTranscribeProgress() {
    _transcribeProgressSub?.cancel();
    _transcribeProgressSub = _recordingService.transcribeProgressStream.listen((
      p,
    ) {
      if (!mounted) return;
      setState(() {
        _transcribeProgress = p.progress;
        _transcribePhase = p.phase;
      });
    });
  }

  /// マイクボタンのタップ：録音していなければ開始する。録音中は、最短
  /// 15秒（[minRecordingDuration]）を過ぎていなければ無視する
  /// （osmCogitoと同じく、あまりに短い音読を止められないようにする）。
  void _onButtonTap() {
    if (!_recording) {
      unawaited(_startRecording());
      return;
    }
    if (!_pastMinRecording) return;
    unawaited(_stopRecording());
  }

  Future<void> _startRecording() async {
    if (!_canRecord || _recording) return;
    await topicSpeechReader.stop();
    if (!mounted) return;
    final consented = await SpeechProcessingConsentDialog.ensure(
      context,
      appSettings.language,
    );
    if (!consented || !mounted) return;
    final started = await _recordingService.startRecording();
    if (!mounted) return;
    if (!started) {
      _showMessage('マイク権限なし'.tr(appSettings.language));
      return;
    }
    setState(() {
      _recording = true;
      _pastMinRecording = false;
      _transcript = null;
    });
    _minRecordingTimer?.cancel();
    _minRecordingTimer = Timer(minRecordingDuration, () {
      if (!mounted) return;
      setState(() => _pastMinRecording = true);
    });
    _autoStopTimer?.cancel();
    _autoStopTimer = Timer(_maxRecordingDuration, () {
      if (!mounted || !_recording) return;
      unawaited(_stopRecording());
    });
  }

  Future<void> _stopRecording() async {
    if (!_recording) return;
    _minRecordingTimer?.cancel();
    _autoStopTimer?.cancel();
    setState(() {
      _recording = false;
      _isTranscribing = true;
      _transcribeProgress = 0;
      _transcribePhase = RecordingSttService.phaseAnalyzing;
    });
    _listenTranscribeProgress();
    try {
      final chunks = await _recordingService.stopAndTranscribe(
        skipOnlineRecognition: true,
      );
      if (!mounted) return;
      final text = chunks.map((c) => c.text).join('').trim();
      setState(() => _transcript = text.isEmpty ? null : text);
      if (text.isEmpty) {
        _showMessage('うまく聞き取れませんでした。もう一度録音してみましょう。'.tr(appSettings.language));
      }
    } finally {
      await _transcribeProgressSub?.cancel();
      _transcribeProgressSub = null;
      if (mounted) setState(() => _isTranscribing = false);
    }
  }

  Future<void> _toggleRecordingPlayback() =>
      toggleLastRecordingPlayback(_recordingService.lastRecordingPath);

  Future<void> _sendToChromeAi() async {
    final transcript = _transcript;
    if (chromeAiAwaitingPaste || transcript == null || _isSaved) return;
    final lang = appSettings.language;
    final plan = LongReadingAiPromptTemplate.buildLaunchPlan(
      article: widget.article,
      transcript: transcript,
      lang: lang,
    );
    await chromeAiSend(
      lang: lang,
      prompt: plan.prompt,
      url: plan.url,
      requiresClipboardPaste: plan.requiresClipboardPaste,
    );
  }

  Future<void> _pasteAndSaveResult() async {
    await runChromeAiPaste(() async {
      final lang = appSettings.language;
      final text = await consumeChromeAiPasteText(lang);
      if (!mounted || text == null) return;

      final parseResult = PronunciationAiResponseParser.parse(
        text,
        languageCode: chromeAiPendingResponseLanguage,
      );

      final now = DateTime.now();
      final transcript = _transcript ?? '';
      if (!parseResult.isSuccess) {
        showChromeAiMessage('Chrome AIの回答を解析できませんでした'.tr(lang));
        final saved = SavedPronunciationCheck.fromLongReading(
          id: '${now.microsecondsSinceEpoch}_${_idRandom.nextInt(1 << 32)}',
          sessionId: _sessionId,
          createdAt: now,
          articleId: widget.article.id,
          articleTitle: widget.article.title,
          transcript: transcript,
          evaluation: null,
          unparsedResponse: text,
        );
        await _storage.save(saved);
        if (!mounted) return;
        setState(() {
          _isSaved = true;
          _hasSavedChecks = true;
        });
        clearChromeAiPendingState();
        return;
      }

      final evaluation = parseResult.evaluation!;
      final saved = SavedPronunciationCheck.fromLongReading(
        id: '${now.microsecondsSinceEpoch}_${_idRandom.nextInt(1 << 32)}',
        sessionId: _sessionId,
        createdAt: now,
        articleId: widget.article.id,
        articleTitle: widget.article.title,
        transcript: transcript,
        evaluation: evaluation,
        unparsedResponse: null,
      );
      await _storage.save(saved);
      if (!mounted) return;
      setState(() {
        _isSaved = true;
        _hasSavedChecks = true;
      });
      clearChromeAiPendingState();
      unawaited(_showResultDialog(evaluation));
    });
  }

  Future<void> _showResultDialog(PronunciationEvaluation evaluation) async {
    if (!mounted) return;
    final lang = appSettings.language;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('評価結果プレビュー'.tr(lang)),
        content: SingleChildScrollView(
          child: PronunciationEvaluationResultView(
            evaluation: evaluation,
            languageCode: lang,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('完了'.tr(lang)),
          ),
        ],
      ),
    );
  }

  Future<void> _onSubmitTap() => chromeAiOnSubmitTap(
    onSend: _sendToChromeAi,
    onPaste: _pasteAndSaveResult,
  );

  /// リセット：録音を即座に中止し、文字起こし結果・送信状態を消して
  /// 音読前の状態に戻す（[MainShellState]がレイヤーを切り替える直前、または
  /// ヘッダー「Ⅴ」再タップの直前に呼び出す。モードそのものは解除しない）。
  Future<void> resetAttempt() async {
    unawaited(topicSpeechReader.stop());
    await stopLastRecordingPlayback();
    await _recordingService.cancel();
    await _recordingService.clearLastRecording();
    _minRecordingTimer?.cancel();
    _autoStopTimer?.cancel();
    stopKeepAliveIfOwned();
    if (!mounted) return;
    setState(() {
      _sessionId = _newSessionId();
      _recording = false;
      _pastMinRecording = false;
      _isTranscribing = false;
      _transcript = null;
      chromeAiAwaitingPaste = false;
      chromeAiPendingResponseLanguage = 'ja';
      chromeAiPendingSentPrompt = null;
      _isSaved = false;
      hideResetUntilNextChange(_resetStateKey());
    });
  }

  Future<void> _openHistory() async {
    await PronunciationHistoryScreen.push(context);
    await _loadHasSavedChecks();
  }

  // ── テスト専用フック ──────────────────────────────────────────────────
  // 実機のネイティブ録音・文字起こしは Flutter widget test 上で再現できない
  // ため、[Layer5ScreenState]と同じく、録音状態の遷移を検証できる最小限の
  // フックのみを用意する。

  @visibleForTesting
  bool get debugRecording => _recording;

  @visibleForTesting
  bool get debugPastMinRecording => _pastMinRecording;

  @visibleForTesting
  String? get debugTranscript => _transcript;

  @visibleForTesting
  void debugForceRecording({bool pastMinRecording = false}) {
    setState(() {
      _recording = true;
      _pastMinRecording = pastMinRecording;
    });
  }

  @visibleForTesting
  void debugCompleteWithTranscript(String transcript) {
    setState(() {
      _recording = false;
      _isTranscribing = false;
      _transcript = transcript;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    final hasTranscript = _transcript != null;
    final showSubmit = hasTranscript && !_isSaved;
    final submitEnabled =
        !chromeAiActionInFlight && (showSubmit || chromeAiAwaitingPaste);

    return Container(
      color: palette.scene,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 短文画面のDiceActionRow（高さ56）と同じ上余白だけ確保する。
              const SizedBox(height: 56),
              const SizedBox(height: 4),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: palette.cardFill,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: palette.cardBorder,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.article.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: palette.textOnCardSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.article.body,
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.7,
                                color: palette.textOnCardPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        chromeAiAwaitingPaste
                            ? 'レイヤーⅤ_長文_貼付待ち'.tr(lang)
                            : 'はっきり声に出して読んでみよう'.tr(lang),
                        style: TextStyle(
                          fontSize: 13,
                          color: palette.textOnSceneSecondary,
                        ),
                      ),
                      if (_recording && !_pastMinRecording) ...[
                        const SizedBox(height: 4),
                        Text(
                          'レイヤーⅤ_長文_最短秒数'.tr(lang),
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.textOnSceneSecondary,
                          ),
                        ),
                      ],
                      if (hasTranscript) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: palette.cardFill,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: palette.cardBorder,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _transcript!,
                            style: TextStyle(
                              fontSize: 14,
                              color: palette.textOnCardPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Visibility(
                visible: !_isSaved,
                maintainState: true,
                maintainAnimation: true,
                maintainSize: true,
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PronunciationMicButton(
                        size: 98,
                        armed: true,
                        recording: _recording,
                        recordingColor: _pastMinRecording
                            ? palette.cardAccent
                            : Colors.redAccent,
                        onTap: _onButtonTap,
                      ),
                      if (_isTranscribing)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: palette.scene,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: TranscribeProgressIndicator(
                                  progress: _transcribeProgress,
                                  phase: _transcribePhase,
                                  compact: true,
                                  active: _isTranscribing,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              PrepLabelRow(
                showExample: _hasSavedChecks,
                exampleIcon: Icons.list_alt_rounded,
                exampleTooltip: '発音チェック結果',
                exampleActive: _hasSavedChecks,
                onExampleTap: _openHistory,
              ),
              const SizedBox(height: 8),
              GenkiTransportRow(
                showPlay: true,
                showReset: _showResetButton,
                showDiagnose: showSubmit || chromeAiAwaitingPaste,
                languageCode: lang,
                playing: isPlayingLastRecording,
                playHasData: _recordingService.lastRecordingPath != null,
                diagnoseHighlighted: showSubmit && !chromeAiAwaitingPaste,
                diagnoseAwaitingPaste: chromeAiAwaitingPaste,
                onPlay: _toggleRecordingPlayback,
                onReset: resetAttempt,
                onDiagnose: submitEnabled ? _onSubmitTap : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
