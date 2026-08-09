import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/pronunciation_ai_prompt_template.dart';
import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings, topicSpeechReader;
import '../../models/pronunciation_practice_session.dart';
import '../../models/pronunciation_evaluation.dart';
import '../../models/recording_mode.dart';
import '../../models/saved_pronunciation_check.dart';
import '../../models/topic_category.dart';
import '../../services/chrome_ai_submit_mixin.dart';
import '../../services/pronunciation_ai_response_parser.dart';
import '../../services/pronunciation_check_storage.dart';
import '../../services/pronunciation_exercise_service.dart';
import '../../services/recording_stt_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ai_import_shared.dart';
import '../../widgets/category_select_field.dart';
import '../../widgets/dice_action_row.dart';
import '../../widgets/genki_transport_row.dart';
import '../../widgets/last_recording_playback_mixin.dart';
import '../../widgets/reset_button_visibility_mixin.dart';
import '../../widgets/layer_help_sheet.dart';
import '../../widgets/prep_label_row.dart';
import '../../widgets/pronunciation_exercise_card.dart';
import '../../widgets/pronunciation_evaluation_result_view.dart';
import '../../widgets/pronunciation_mic_button.dart';
import '../../widgets/speech_processing_consent_dialog.dart';
import '../../widgets/transcribe_progress_indicator.dart';
import 'pronunciation_exercise_import_screen.dart';
import 'pronunciation_history_screen.dart';

/// レイヤーⅤ：うまく日本語を発音できない。
///
/// 「つ」「ざ・ず・ぞ」「ラ行」「長音」「促音」の5カテゴリに特化した
/// 10問（各カテゴリ2問）の短文音読セッション。1問ずつ「マイクをタップ
/// （または断続以外のモードなら自動）して録音開始→もう一度タップして
/// 録音終了→端末STT」を行い、全問回答後にまとめてChrome AIへ送信して
/// 参考評価を受け取る（送信自体は録音音声ではなく、期待文と端末STT結果の
/// テキストのみ）。
///
/// レイアウトはレイヤーⅡ〜Ⅳ（[DiceActionRow]・[CategorySelectField]・
/// [PrepLabelRow]・[GenkiTransportRow]）と同じ部品・同じ並び順で揃え、
/// このレイヤーで使わないボタンは`visible: false`でゴースト化する
/// （枠だけ確保し、レイヤーを切り替えたときにボタン位置がズレないため）。
/// 読み上げ（TTS）は使わない。中央の大きなボタンはレイヤーⅡ〜Ⅳと同じ
/// サイコロ→スピーカーの2アイコン制を踏襲し、すべてタップだけで操作する
/// （長押しは使わない。実機・特にAndroidで、長押し中に他のジェスチャーと
/// 競合して録音が途中で打ち切られる不具合が報告されたための設計変更）。
///
/// レイヤーⅢの「45」ピルに相当する位置に、[RecordingMode]（断続/
/// 半連続/連続）を切り替えるトグル（[DiceActionRow.fortyFiveIcon]）を置く。
/// タップのたびに断続→半連続→連続→断続…と巡回する（[RecordingModeX.next]）。
/// - 断続（既定）：サイコロタップで問題を表示してマイクに切り替えるが、
///   録音はマイクをタップするまで始まらない。録音停止後は文字起こし結果を
///   表示してサイコロに戻り、次の問題へ進むには改めてサイコロをタップする。
/// - 半連続：サイコロタップと同時に録音まで自動的に始まる。停止後の挙動は
///   断続と同じく、結果を表示してサイコロに戻る（次へは改めてサイコロを
///   タップする）。
/// - 連続：サイコロタップ（1問目）または録音停止後に自動的に表示される
///   次の問題（2問目以降）と同時に、録音まで自動的に始まる。結果は一切
///   表示せず、そのまま10問目まで進み続ける。
class Layer5Screen extends StatefulWidget {
  const Layer5Screen({super.key});

  @override
  State<Layer5Screen> createState() => Layer5ScreenState();
}

class Layer5ScreenState extends State<Layer5Screen>
    with
        WidgetsBindingObserver,
        AiImportKeepAliveMixin,
        ChromeAiSubmitMixin,
        ResetButtonVisibilityMixin,
        LastRecordingPlaybackMixin {
  final _recordingService = RecordingSttService();
  final _storage = PronunciationCheckStorage();
  final _idRandom = Random();

  late PronunciationPracticeSession _session;
  late String _sessionId;

  bool _actionInFlight = false;
  bool _isTranscribing = false;
  bool _isSessionSaved = false;
  bool _hasSavedChecks = false;
  double _transcribeProgress = 0;
  String _transcribePhase = '';
  StreamSubscription<TranscribeProgress>? _transcribeProgressSub;

  /// 録音開始処理の途中かどうか（マイクをタップしてから実際に録音が
  /// 始まるまでの非同期区間）。この間は二重タップ防止のため次のタップを
  /// 受け付けない（[_canRecord]がfalseになる）。
  bool _startingRecording = false;

  /// レイヤーⅡ〜Ⅳのサイコロ→スピーカーと同じ2アイコン制。falseなら
  /// サイコロ（問題文は隠す）、trueならマイク（問題文を表示し、タップで
  /// 録音を開始・終了できる）を表示する。録音終了のタップで必ずfalseへ戻る。
  bool _armed = false;

  bool get _allAnswered => _session.questions.every(
    (q) =>
        q.status == PronunciationQuestionStatus.completed ||
        q.status == PronunciationQuestionStatus.failed,
  );

  bool get _recordingBusy {
    final status = _session.current.status;
    return _startingRecording ||
        _isTranscribing ||
        status == PronunciationQuestionStatus.recording ||
        status == PronunciationQuestionStatus.transcribing;
  }

  bool get _canRecord =>
      !_actionInFlight &&
      !chromeAiActionInFlight &&
      !chromeAiAwaitingPaste &&
      !_recordingBusy;

  /// 問題文（カード）を表示するかどうか。armed中（マイク表示）は常に表示し、
  /// 未着手（waiting）でサイコロ表示中のみ隠す。回答済み（completed/failed）
  /// はサイコロに戻ったあとも結果を見えたままにする。
  bool get _questionVisible =>
      _armed || _session.current.status != PronunciationQuestionStatus.waiting;

  String _resetStateKey() => [
    _session.currentIndex.toString(),
    _session.current.status.name,
    appSettings.layer5RecordingMode.name,
    _armed.toString(),
    _allAnswered.toString(),
    chromeAiAwaitingPaste.toString(),
    _isSessionSaved.toString(),
    _recordingService.lastRecordingPath ?? '',
  ].join('|');

  bool get _showResetButton => showResetButton(_resetStateKey());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // [MainShell]に一度生成されたら破棄されずキャッシュされ続けるため、
    // 設定画面で言語を変えて戻ってきただけでは再構築されず表示が古い言語の
    // ままになる。appSettingsの変更を直接購読し、その場で再描画する。
    appSettings.addListener(_onSettingsChanged);
    _session = _newSession();
    _sessionId = _newSessionId();
    // initStateは同期処理しかできないため、まず組み込み25問だけでセッションを
    // 組み立てる。取り込み済み課題（SharedPreferences）はここで非同期に読み込み、
    // まだ何も答えていなければ統合プールで引き直す。
    unawaited(_refreshSessionWithFullPoolIfUntouched());
    unawaited(_loadHasSavedChecks());
    initLastRecordingPlayback();
  }

  PronunciationPracticeSession _newSession() =>
      const PronunciationExerciseService().buildSession();

  bool get _sessionUntouched => _session.questions.every(
    (q) => q.status == PronunciationQuestionStatus.waiting,
  );

  /// 組み込み課題と取り込み済み課題を統合したプールでセッションを引き直す
  /// （まだ何も答えていない場合のみ）。抽選時に組み込み・取り込み済み両方の
  /// 課題が対象になるようにする。
  Future<void> _refreshSessionWithFullPoolIfUntouched() async {
    if (!_sessionUntouched) return;
    final pool = await const PronunciationExerciseService().loadFullPool();
    if (!mounted || !_sessionUntouched) return;
    setState(() {
      _session = const PronunciationExerciseService().buildSession(pool: pool);
    });
  }

  Future<void> _loadHasSavedChecks() async {
    final checks = await _storage.loadAll();
    if (!mounted) return;
    setState(() => _hasSavedChecks = checks.isNotEmpty);
  }

  String _newSessionId() =>
      'sess_${DateTime.now().microsecondsSinceEpoch}_${_idRandom.nextInt(1 << 32)}';

  void _onSettingsChanged() => setState(() {});

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    appSettings.removeListener(_onSettingsChanged);
    stopKeepAliveIfOwned();
    disposeLastRecordingPlayback();
    _transcribeProgressSub?.cancel();
    _recordingService.dispose();
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

  /// ボタンをタップ：状態に応じて動作が変わる。
  /// - サイコロ表示中：[_onDiceTap]（最初の問題を表示する）。
  /// - マイク表示中・録音していない：録音開始。
  /// - マイク表示中・録音中（背景が赤）：録音終了→自動的に次の問題へ進み、
  ///   マイク（背景透明）のまま次の録音に備える（[_onMicTapToStop]）。
  void _onButtonTap() {
    if (_actionInFlight) return;
    if (!_armed) {
      unawaited(_onDiceTap());
      return;
    }
    if (_session.current.status == PronunciationQuestionStatus.recording) {
      unawaited(_onMicTapToStop());
    } else if (_canRecord) {
      unawaited(_startRecording());
    }
    // それ以外（録音開始処理中・文字起こし中）はタップを無視する。
  }

  /// サイコロをタップ：未着手の問題ならそのまま表示してマイクに切り替える。
  /// 回答済みなら次の問題へ進めてから表示する（次の問題がなければ何もしない
  /// ＝10問目まで答え終わったら、送信ボタンに役目を譲る）。
  /// 断続モード以外（半連続/連続）のときだけ、表示と同時に録音を始める。
  Future<void> _onDiceTap() async {
    if (_actionInFlight || _recordingBusy) return;
    final status = _session.current.status;
    final answered =
        status == PronunciationQuestionStatus.completed ||
        status == PronunciationQuestionStatus.failed;
    if (!answered) {
      setState(() => _armed = true);
      await _autoStartRecording();
      return;
    }
    if (!_session.hasNext) return;
    setState(() => _actionInFlight = true);
    try {
      await stopLastRecordingPlayback();
      if (!mounted) return;
      setState(() {
        _session.next();
        _armed = true;
      });
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
    await _autoStartRecording();
  }

  /// マイク（赤＝録音中）をタップ：録音を停止→文字起こしし、結果を
  /// 現在の問題に記録する。ここから先はモードで分岐する：
  /// - 連続モード：サイコロを経由せず自動的に次の問題へ進め、録音も
  ///   自動的に始める（結果は表示しない）。次の問題がなければ（10問目
  ///   だった場合）armedをfalseに戻す（送信ボタンに役目を譲るため、
  ///   [_allAnswered]により表示ごと隠れる）。
  /// - 断続モード：次の問題へは進めず、armedをfalseに戻してサイコロを
  ///   表示する（[_questionVisible]により、文字起こし結果はそのまま
  ///   見える）。次の問題へ進むには改めてサイコロをタップする。
  ///
  /// レイヤーⅣと同様、直近の録音（[RecordingSttService.lastRecordingPath]）
  /// は次の問題へ進んでもここでは消さない（▶︎ボタンの青地表示
  /// ［[GenkiTransportRow.playHasData]］が維持される）。録音データは
  /// [resetAttempt]でのみ消去する。
  Future<void> _onMicTapToStop() async {
    await _stopRecording();
    if (!mounted) return;
    if (!appSettings.layer5RecordingMode.autoAdvancesQuestions) {
      setState(() => _armed = false);
      return;
    }
    if (!_session.hasNext) {
      setState(() => _armed = false);
      return;
    }
    await stopLastRecordingPlayback();
    if (!mounted) return;
    setState(() {
      _session.next();
      _armed = true;
    });
    await _autoStartRecording();
  }

  /// 断続モード以外（半連続/連続）のときだけ、問題が表示され次第自動的に
  /// 録音を開始する（断続モードでは、マイクをタップするまで録音を始めない）。
  Future<void> _autoStartRecording() async {
    if (!appSettings.layer5RecordingMode.autoStartsRecording) return;
    if (!mounted || !_armed || !_canRecord) return;
    await _startRecording();
  }

  /// レイヤーⅤの録音モードを断続→半連続→連続→断続…の順で切り替える。
  void _toggleRecordingMode() {
    setState(() {
      appSettings.layer5RecordingMode = appSettings.layer5RecordingMode.next;
    });
  }

  Future<void> _startRecording() async {
    if (!_canRecord) return;
    _startingRecording = true;
    await topicSpeechReader.stop();
    if (!mounted) {
      _startingRecording = false;
      return;
    }
    final consented = await SpeechProcessingConsentDialog.ensure(
      context,
      appSettings.language,
    );
    if (!consented || !mounted) {
      _startingRecording = false;
      return;
    }
    final started = await _recordingService.startRecording();
    _startingRecording = false;
    if (!mounted) return;
    if (!started) {
      _showMessage('マイク権限なし'.tr(appSettings.language));
      return;
    }
    setState(() => _session.setStatus(PronunciationQuestionStatus.recording));
  }

  Future<void> _stopRecording() async {
    if (_session.current.status != PronunciationQuestionStatus.recording) {
      return;
    }
    setState(() {
      _isTranscribing = true;
      _transcribeProgress = 0;
      _transcribePhase = RecordingSttService.phaseAnalyzing;
      _session.setStatus(PronunciationQuestionStatus.transcribing);
    });
    _listenTranscribeProgress();
    try {
      final chunks = await _recordingService.stopAndTranscribe();
      if (!mounted) return;
      final text = chunks.map((c) => c.text).join('').trim();
      setState(() {
        if (text.isEmpty) {
          _session.markFailed();
        } else {
          _session.completeWithResult(text);
        }
      });
      if (text.isEmpty) {
        _showMessage('うまく聞き取れませんでした。もう一度録音してみましょう。'.tr(appSettings.language));
      }
    } finally {
      await _transcribeProgressSub?.cancel();
      _transcribeProgressSub = null;
      if (mounted) setState(() => _isTranscribing = false);
    }
  }

  Future<void> _toggleRecordingPlayback() async {
    if (_actionInFlight) return;
    await toggleLastRecordingPlayback(_recordingService.lastRecordingPath);
  }

  /// [chromeAiSend]自体が[chromeAiActionInFlight]の二重タップ防止を持つため、
  /// ここでは[_actionInFlight]で包まない（ダッシュボードと同じ）。
  Future<void> _sendToChromeAi() async {
    if (_actionInFlight ||
        chromeAiAwaitingPaste ||
        !_allAnswered ||
        _isSessionSaved) {
      return;
    }
    final lang = appSettings.language;
    final prompt = PronunciationAiPromptTemplate.evaluationPrompt(
      questions: _session.questions,
      lang: lang,
    );
    final url = PronunciationAiPromptTemplate.evaluationSearchUrl(
      questions: _session.questions,
      lang: lang,
    );
    await chromeAiSend(lang: lang, prompt: prompt, url: url);
  }

  /// クリップボードのChrome AI回答を解析して保存する（レイヤーⅠと同じく、
  /// 解析に失敗した場合でも回答原文は
  /// [SavedPronunciationCheck.unparsedResponse]として残す）。
  /// 排他は[runChromeAiPaste]（[chromeAiActionInFlight]）に任せる。
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
      if (!parseResult.isSuccess) {
        showChromeAiMessage('Chrome AIの回答を解析できませんでした'.tr(lang));
        final saved = SavedPronunciationCheck.fromSession(
          id: '${now.microsecondsSinceEpoch}_${_idRandom.nextInt(1 << 32)}',
          sessionId: _sessionId,
          createdAt: now,
          session: _session,
          evaluation: null,
          unparsedResponse: text,
        );
        await _storage.save(saved);
        if (!mounted) return;
        setState(() {
          _isSessionSaved = true;
          _hasSavedChecks = true;
        });
        clearChromeAiPendingState();
        return;
      }

      final evaluation = parseResult.evaluation!;
      final saved = SavedPronunciationCheck.fromSession(
        id: '${now.microsecondsSinceEpoch}_${_idRandom.nextInt(1 << 32)}',
        sessionId: _sessionId,
        createdAt: now,
        session: _session,
        evaluation: evaluation,
        unparsedResponse: null,
      );
      await _storage.save(saved);
      if (!mounted) return;
      setState(() {
        _isSessionSaved = true;
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

  /// リセット：録音を即座に中止し、新しい10問セッションを抽選し直して
  /// 最初の問題（1問目）に戻す。[MainShell]がレイヤーを切り替える直前に、
  /// 非表示になるレイヤーに対して呼び出す。
  Future<void> resetAttempt() async {
    unawaited(topicSpeechReader.stop());
    await stopLastRecordingPlayback();
    await _recordingService.cancel();
    await _recordingService.clearLastRecording();
    stopKeepAliveIfOwned();
    if (!mounted) return;
    setState(() {
      _session = _newSession();
      _sessionId = _newSessionId();
      _isTranscribing = false;
      chromeAiAwaitingPaste = false;
      chromeAiPendingResponseLanguage = 'ja';
      chromeAiPendingSentPrompt = null;
      _isSessionSaved = false;
      _actionInFlight = false;
      _startingRecording = false;
      _armed = false;
      hideResetUntilNextChange(_resetStateKey());
    });
    unawaited(_refreshSessionWithFullPoolIfUntouched());
  }

  Future<void> _openHistory() async {
    await PronunciationHistoryScreen.push(context);
    await _loadHasSavedChecks();
  }

  /// 発音課題の取り込み画面を開く。戻ってきたときにセッションの途中でなければ
  /// （waiting状態のまま何も答えていなければ）、取り込んだ課題も含めて
  /// セッションを引き直す。
  Future<void> _openExerciseImport() async {
    await PronunciationExerciseImportScreen.push(context);
    await _refreshSessionWithFullPoolIfUntouched();
  }

  /// 「＋」長押し：録音モード〜貼り付けまでのステップを表示する。
  void _showUsageHelp() {
    final lang = appSettings.language;
    LayerHelpSheet.show(
      context,
      title: '操作方法'.tr(lang),
      lines: [
        LayerHelpLine(
          text: 'レイヤーⅤ_使い方_録音モード'.tr(lang),
          icon: Icons.more_horiz_rounded,
        ),
        LayerHelpLine(text: 'レイヤーⅤ_使い方_サイコロ'.tr(lang), icon: Icons.casino),
        LayerHelpLine(text: 'レイヤーⅤ_使い方_マイク'.tr(lang), icon: Icons.mic_rounded),
        LayerHelpLine(text: 'レイヤーⅤ_使い方_10問'.tr(lang)),
        LayerHelpLine(text: 'レイヤーⅤ_使い方_送信'.tr(lang), icon: Icons.send_rounded),
        LayerHelpLine(text: 'レイヤーⅤ_使い方_貼り付け'.tr(lang)),
      ],
    );
  }

  // ── テスト専用フック ──────────────────────────────────────────────────
  // 実機のネイティブ録音・文字起こしは Flutter widget test 上で再現できない
  // ため、セッション進行（次へ・完了状態の遷移）とそれに連動するボタン状態を
  // 検証できるよう、公開APIである[PronunciationPracticeSession]を最小限
  // 経由させるフックのみを用意する。

  @visibleForTesting
  PronunciationPracticeSession get debugSession => _session;

  @visibleForTesting
  bool get debugArmed => _armed;

  /// ネイティブの録音を経由せず、現在の問題を「録音中」状態にする。
  /// 実際のマイクタップ→タップで停止のフロー（[_onMicTapToStop]、ひいては
  /// サイコロを経由しない自動的な次の問題への遷移）をテストで検証するために
  /// 使う（[RecordingSttService.stopAndTranscribe]は、実際に録音を開始して
  /// いなければプラットフォームチャンネルを呼ばず空リストを返すため、この
  /// フックの後に実際にマイクアイコンをタップして止めても安全に完了する）。
  @visibleForTesting
  void debugForceRecordingStatus() {
    setState(() => _session.setStatus(PronunciationQuestionStatus.recording));
  }

  /// 実際の録音では、指を離した時点で必ずarmedがfalse（サイコロ表示）に
  /// 戻ってから結果が確定するため、ここでも同じ不変条件を再現する。
  @visibleForTesting
  void debugCompleteCurrentQuestion(String sttResult) {
    setState(() {
      _session.completeWithResult(sttResult);
      _armed = false;
    });
  }

  @visibleForTesting
  void debugMarkCurrentFailed() {
    setState(() {
      _session.markFailed();
      _armed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    final current = _session.current;
    final status = current.status;
    final showSubmit = _allAnswered && !_isSessionSaved;
    final submitEnabled = !_actionInFlight &&
        !chromeAiActionInFlight &&
        (showSubmit || chromeAiAwaitingPaste);

    return Container(
      color: palette.scene,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DiceActionRow(
                show45: true,
                show60: false,
                show15Plus60: false,
                fortyFiveIcon: switch (appSettings.layer5RecordingMode) {
                  RecordingMode.intermittent => Icons.more_horiz_rounded,
                  RecordingMode.semiContinuous => Icons.linear_scale_rounded,
                  RecordingMode.continuous => Icons.horizontal_rule_rounded,
                },
                fortyFiveTooltip: switch (appSettings.layer5RecordingMode) {
                  RecordingMode.intermittent => '断続モード',
                  RecordingMode.semiContinuous => '半連続モード',
                  RecordingMode.continuous => '連続モード',
                },
                fortyFiveActive:
                    appSettings.layer5RecordingMode !=
                    RecordingMode.intermittent,
                // 断続＝透明（非active時の既定表示）、半連続＝青、連続＝橙で
                // 一目でモードを見分けられるようにする。
                fortyFiveActiveFill: switch (appSettings.layer5RecordingMode) {
                  RecordingMode.intermittent => null,
                  RecordingMode.semiContinuous => palette.accentColor,
                  RecordingMode.continuous => palette.cardAccent,
                },
                // 余白ゼロ・枠線なしで、アイコンをできるだけ大きく表示する
                // （国旗・目のアイコン等と同じ差し替え方式）。
                fortyFiveShowBorder: false,
                fortyFiveHorizontalPadding: 0,
                fortyFiveIconSize: 48,
                onFortyFiveTap: _toggleRecordingMode,
                showAdd: true,
                addIcon: Icons.add_rounded,
                addTooltip: '発音課題を取り込む',
                onAddTap: _openExerciseImport,
                onAddLongPress: _showUsageHelp,
              ),
              const SizedBox(height: 4),
              // 分野（お題カテゴリ）セレクタはレイヤーⅤでは使わないが、
              // レイアウトの高さを他レイヤーと揃えるため枠だけ確保して隠す。
              Visibility(
                visible: false,
                maintainState: true,
                maintainAnimation: true,
                maintainSize: true,
                child: CategorySelectField(
                  selected: TopicCategory.daily,
                  onChanged: (_) {},
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: SingleChildScrollView(
                  child: _questionVisible
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PronunciationExerciseCard(
                              exercise: current.exercise,
                              questionNumber: _session.currentIndex + 1,
                              totalQuestions: _session.questionCount,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              chromeAiAwaitingPaste
                                  ? 'Chromeから戻ったら貼り付けボタンを押して、発音チェック結果を保存しよう'.tr(
                                      lang,
                                    )
                                  : 'はっきり声に出して読んでみよう'.tr(lang),
                              style: TextStyle(
                                fontSize: 13,
                                color: palette.textOnSceneSecondary,
                              ),
                            ),
                            if (status ==
                                    PronunciationQuestionStatus.completed &&
                                current.sttResult != null) ...[
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
                                  current.sttResult!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: palette.textOnCardPrimary,
                                  ),
                                ),
                              ),
                            ],
                            if (status ==
                                PronunciationQuestionStatus.failed) ...[
                              const SizedBox(height: 12),
                              Text(
                                'うまく聞き取れませんでした。もう一度録音してみましょう。'.tr(lang),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: palette.textOnSceneSecondary,
                                ),
                              ),
                            ],
                          ],
                        )
                      : Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(minHeight: 160),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: palette.cardFill,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: palette.cardBorder,
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'サイコロをタップして問題を表示'.tr(lang),
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              fontSize: 15,
                              color: palette.textOnCardSecondary,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              // 10問すべてに回答したら、もう進める先の問題がないためサイコロ
              // ボタンごと隠す（送信ボタンに役目を譲る）。枠だけ確保し、
              // レイアウトが上下にガタつかないようにする。
              Visibility(
                visible: !_allAnswered,
                maintainState: true,
                maintainAnimation: true,
                maintainSize: true,
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PronunciationMicButton(
                        size: 98,
                        armed: _armed,
                        recording:
                            status == PronunciationQuestionStatus.recording,
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
              // 結論/理由（PREPガイド）はレイヤーⅤでは使わないため非表示のまま、
              // 「例示」の枠だけ、上段の＋から移した発音チェック結果一覧に転用する。
              // 保存済み結果があるときだけ表示する。
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
