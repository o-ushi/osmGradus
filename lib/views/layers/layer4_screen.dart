import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/prep_hit_ai_prompt_template.dart';
import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings, topicSpeechReader;
import '../../models/drawn_topic.dart';
import '../../models/layer4_prompt_reveal_mode.dart';
import '../../models/practice_timer_models.dart';
import '../../models/question_prompt.dart';
import '../../models/saved_scoring_result.dart';
import '../../models/question_prompt_draw_selection.dart';
import '../../navigation/app_routes.dart';
import '../../services/alarm_sound_service.dart';
import '../../services/chrome_ai_submit_mixin.dart';
import '../../services/layer2_sample_answer_chrome_ai.dart';
import '../../services/jsst_scoring_service.dart';
import '../../services/prep_hit_ai_response_parser.dart';
import '../../services/question_prompt_service.dart';
import '../../services/recording_stt_service.dart';
import '../../services/scoring_result_storage.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ai_import_shared.dart';
import '../../widgets/question_prompt_draw_select_field.dart';
import '../../widgets/dice_action_row.dart';
import '../../widgets/dice_topic_card.dart';
import '../../widgets/genki_transport_row.dart';
import '../../widgets/google_ai_send_consent_dialog.dart';
import '../../widgets/layer_help_sheet.dart';
import '../../widgets/layer_numeral_badge.dart';
import '../../widgets/prep_label_row.dart';
import '../../widgets/question_prompt_nav_row.dart';
import '../../widgets/topic_speaker_timer_button.dart';
import '../../widgets/transcribe_progress_indicator.dart';
import '../../widgets/last_recording_playback_mixin.dart';
import '../../widgets/reset_button_visibility_mixin.dart';
import '../topics/topic_add_flow.dart';
import 'practice_layer_screen.dart';

/// [Layer4ScreenState]は[ChromeAiSubmitMixin]の状態
/// （`chromeAiAwaitingPaste`等）を、PREP・的中度の紙飛行機往復と解答例
/// （[Layer2SampleAnswerMixin]）往復の**両方**で共有する。用途を区別しないと
/// 「紙飛行機待ち中に解答例タップ→誤って模範解答として保存」
/// 「解答例待ち中にアプリ復帰→PREP側が誤作動」が起こる（Step 3）。
enum _ChromeAiPendingKind { sampleAnswer, prepHit }

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
  const Layer4Screen({
    super.key,
    this.fixedPrompt,
    this.onGoToLayer5,
    this.canGoPrevious = false,
    this.canGoNext = false,
    this.onGoPrevious,
    this.onGoNext,
  });

  /// 非nullなら「一覧から選ぶ」経由（Step 5）。抽選（サイコロ）・カテゴリ選択を
  /// 隠し、この問題文で固定して録音・採点フローを進める。採点結果は
  /// [SavedScoringResult]としての保存に加え、この問題文の
  /// `jsstScore`/`hitScore`/`prepScore`にも反映する。
  final QuestionPrompt? fixedPrompt;

  /// [fixedPrompt]がnullでないとき、AI評価（PREP・的中度）が届いた後の
  /// 「V」タップで呼ぶ（[MainShellState.openPromptDetailInLayer]への参照）。
  final VoidCallback? onGoToLayer5;

  /// [fixedPrompt]がnullでないとき、隠された「カテゴリ」枠に前後の問題文へ
  /// 移動する▲▼ボタン（[QuestionPromptNavRow]）を表示するための状態。
  /// [Layer4QuestionPromptDetailScreen]から渡される
  /// （録音中などは呼び出し側の`_confirmCanNavigate`が移動を拒否する）。
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback? onGoPrevious;
  final VoidCallback? onGoNext;

  @override
  State<Layer4Screen> createState() => Layer4ScreenState();
}

class Layer4ScreenState extends PracticeLayerScreenState<Layer4Screen>
    with
        WidgetsBindingObserver,
        AiImportKeepAliveMixin,
        ChromeAiSubmitMixin,
        ResetButtonVisibilityMixin,
        LastRecordingPlaybackMixin,
        Layer2SampleAnswerMixin {
  final _storage = ScoringResultStorage();
  final _questionPromptService = QuestionPromptService();
  final _idRandom = Random();

  List<SavedScoringResult> _savedResults = [];
  bool _isEvaluating = false;
  double _transcribeProgress = 0;
  String _transcribePhase = '';
  StreamSubscription<TranscribeProgress>? _transcribeProgressSub;

  /// 直近にJSST採点・保存した結果（PREP・的中度の「送信」対象）。
  /// 新しいお題を引く／リセットすると解除する（Step 8）。
  SavedScoringResult? _lastResult;

  /// 「ランダム」（[widget.fixedPrompt] == null）で抽選済みの問題文（Step 4）。
  /// Ⅱランダムと同じ[QuestionPromptService]プールから引く。「一覧から選ぶ」
  /// では常にnull（[widget.fixedPrompt]が既に確定済みのため使わない）。
  QuestionPrompt? _drawnPrompt;

  /// この画面が今対象にしている問題文（一覧＝[widget.fixedPrompt]、
  /// ランダム＝抽選済みの[_drawnPrompt]）。採点・解答例の保存先の
  /// 唯一の参照元にする（Step 4でランダムにも紐づけ先ができたため）。
  QuestionPrompt? get _activePrompt => widget.fixedPrompt ?? _drawnPrompt;

  /// タートルモード（Step 3）で問題文を表示済み・読み上げ待ちの状態か。
  /// idleのままサイコロ/開始アイコンをスピーカーに差し替え、次のタップで
  /// [PracticeLayerScreenState.speakDrawnTopic]を呼ぶ目印にする。ラピッド
  /// モードでは常にfalseのまま（[drawAndSpeak]が抽選と読み上げを1タップで
  /// まとめて行うため）。
  bool _awaitingSpeakAfterPreview = false;

  /// [widget.fixedPrompt.sampleAnswer]のローカルな写し（Step 3）。
  /// 親[Layer4QuestionPromptDetailScreen]が持つ`_prompt`は解答例保存後も
  /// 再読込されないため、[saveSampleAnswer]直後にこの画面自身の表示へ
  /// 即時反映するために保持する（[_persistScoreToPrompt]の評点と同じ
  /// 「参照元は書き換えず、次回読込で追従する」方針）。
  String _sampleAnswer = '';

  /// 現在保留中のChrome AI往復がどちらの用途か（[_ChromeAiPendingKind]）。
  _ChromeAiPendingKind? _chromeAiPendingKind;

  bool get _isPrepHitAwaitingPaste =>
      chromeAiAwaitingPaste &&
      _chromeAiPendingKind == _ChromeAiPendingKind.prepHit;

  bool get _isSampleAnswerAwaitingPaste =>
      chromeAiAwaitingPaste &&
      _chromeAiPendingKind == _ChromeAiPendingKind.sampleAnswer;

  String _resetStateKey() => [
    buttonPhase.name,
    drawSelection.labelKey,
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
    final fixedPrompt = widget.fixedPrompt;
    if (fixedPrompt != null) {
      selectedCategory = fixedPrompt.category;
      _sampleAnswer = fixedPrompt.sampleAnswer;
    }
    _loadSavedResults();
    initLastRecordingPlayback();
  }

  /// [Layer4QuestionPromptDetailScreen]が上下スワイプで前後の問題文へ移動
  /// するとき、この画面自身は破棄せず[fixedPrompt]だけ差し替えて再利用する
  /// （[GlobalKey]を安定させ、[isBusy]を呼び出し側から参照し続けられるように
  /// するため）。そのため、対象の問題文が変わったらここで明示的に
  /// [resetAttempt]し、前の問題文の読み上げ・カウントダウン・録音・
  /// 採点結果・AI貼り付け待ちの状態を持ち越さないようにする。
  @override
  void didUpdateWidget(Layer4Screen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newPrompt = widget.fixedPrompt;
    if (newPrompt != null && newPrompt.id != oldWidget.fixedPrompt?.id) {
      selectedCategory = newPrompt.category;
      _sampleAnswer = newPrompt.sampleAnswer;
      unawaited(resetAttempt());
    }
  }

  /// [fixedPrompt]モードでの抽選スキップ。固定の問題文をそのまま
  /// [DrawnTopic]として返す（カテゴリ・シチュエーション条件も引き継ぐ）。
  /// ランダムモードでは[drawAndSpeak]が事前に[_drawnPrompt]を確定させて
  /// いるので、ここではそれをそのまま[DrawnTopic]化するだけでよい（Step 4）。
  /// [super.pickTopic]（[TopicService]題材バンク抽選）へのフォールバックは、
  /// [drawAndSpeak]の呼び出し方を守る限り実際には通らない防御的な分岐
  /// （[_activePrompt]が必ず確定済みのため）。
  @override
  Future<DrawnTopic> pickTopic() async {
    final prompt = _activePrompt;
    if (prompt == null) return super.pickTopic();
    return DrawnTopic(
      category: prompt.category,
      text: prompt.body,
      subtext: prompt.situationCondition,
    );
  }

  /// [drawnTopic]が未設定（抽選/開始前）のとき、[fixedPrompt]モードでは
  /// 本文カードに問題文をあらかじめ表示しておく（一覧経由で既に決まっている
  /// 問題文のため、サイコロ待ちのプレースホルダーを見せる必要がない）。
  DrawnTopic? get _displayedTopic => drawnTopic ?? _fixedDisplayTopic;

  DrawnTopic? get _fixedDisplayTopic {
    final prompt = widget.fixedPrompt;
    if (prompt == null) return null;
    return DrawnTopic(
      category: prompt.category,
      text: prompt.body,
      subtext: prompt.situationCondition,
    );
  }

  /// [_activePrompt]の`jsstScore`/`hitScore`/`prepScore`を更新する
  /// （渡さなかった軸は変更しない）。[QuestionPromptService.update]は
  /// 対象の最新値を読み直してから書くため、複数回の採点・AI評価が
  /// 別タイミングで来ても互いを上書きしない。ランダムでも抽選済みの
  /// 問題文（[_drawnPrompt]）に反映する（Step 4）。
  Future<void> _persistScoreToPrompt({
    int? jsstScore,
    int? hitScore,
    int? prepScore,
  }) async {
    final prompt = _activePrompt;
    if (prompt == null) return;
    final current = await _questionPromptService.loadById(prompt.id);
    if (current == null) return;
    await _questionPromptService.update(
      current.copyWith(
        jsstScore: jsstScore,
        hitScore: hitScore,
        prepScore: prepScore,
      ),
    );
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

  /// PREP・的中度と解答例は同じ[chromeAiAwaitingPaste]を共有するため、
  /// 保留中の用途（[_chromeAiPendingKind]）で復帰時の処理先を振り分ける
  /// （Step 3「AI往復の衝突」）。解答例側は[Layer2SampleAnswerMixin]自身の
  /// 実装（`super`。mixinの適用順で直上に来る）に委ねる。
  @override
  void onResumedFromExternalApp() {
    if (!chromeAiAwaitingPaste) return;
    if (_chromeAiPendingKind == _ChromeAiPendingKind.sampleAnswer) {
      super.onResumedFromExternalApp();
      return;
    }
    unawaited(_pasteAndSaveResult());
  }

  /// [_chromeAiPendingKind]がsampleAnswerのときだけⅡと同じ解答例専用の
  /// 同意ダイアログを出す。それ以外（PREP・的中度）は
  /// PREP・的中度専用の文言を出す
  /// （`super.confirmChromeAiSend`は[Layer2SampleAnswerMixin]の実装に
  /// なるため、ここで明示的に専用ダイアログを指定する）。
  @override
  Future<bool> confirmChromeAiSend(String lang) {
    if (_chromeAiPendingKind == _ChromeAiPendingKind.sampleAnswer) {
      return super.confirmChromeAiSend(lang);
    }
    return GoogleAiSendConsentDialog.confirm(
      context,
      languageCode: lang,
      titleKey: 'レイヤーⅣ_PREP_Google送信確認_タイトル',
      bodyKey: 'レイヤーⅣ_PREP_Google送信確認_本文',
    );
  }

  /// 用途分岐（[_chromeAiPendingKind]）も一緒に解除する。PREP・解答例
  /// どちらの往復から呼ばれても、この画面の唯一の実装がまとめて処理する。
  @override
  void clearChromeAiPendingState({VoidCallback? onCleared}) {
    _chromeAiPendingKind = null;
    super.clearChromeAiPendingState(onCleared: onCleared);
  }

  @override
  QuestionPrompt? get sampleAnswerPrompt =>
      _activePrompt?.copyWith(sampleAnswer: _sampleAnswer);

  /// [QuestionPromptService.update]は対象の最新値を読み直してから書くため、
  /// 採点結果（[_persistScoreToPrompt]）と解答例が別タイミングで届いても
  /// 互いを上書きしない。保存後はこの画面のローカル表示（[_sampleAnswer]）
  /// だけ即時更新する（親の`fixedPrompt`自体は次回読込まで古いままでよい、
  /// 評点の反映と同じ方針）。ランダムでも抽選済みの問題文（[_drawnPrompt]）
  /// へ保存する（Step 4）。
  @override
  Future<void> saveSampleAnswer(String text) async {
    final prompt = _activePrompt;
    if (prompt == null) return;
    final current = await _questionPromptService.loadById(prompt.id);
    final base = current ?? prompt;
    await _questionPromptService.update(base.copyWith(sampleAnswer: text));
    if (!mounted) return;
    setState(() => _sampleAnswer = text);
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
  /// 解除する（どの結果への送信か分からなくなるのを防ぐ）。ランダム
  /// （[widget.fixedPrompt] == null）では、Ⅱランダムと同じ
  /// [QuestionPromptService]のプールから先に抽選し、[pickTopic]が読む
  /// [_drawnPrompt]を確定させてから[super.drawAndSpeak]を呼ぶ（Step 4）。
  /// 問題文が0件のときはⅡランダムと同じく黙って何もしない
  /// （エラー表示・サイコロ無効化はしない）。
  /// ランダムモードの問題文選定＋直前の結果クリアだけを行う（[drawAndSpeak]
  /// の「読み上げ開始」より前の部分）。ラピッドの1タップ抽選と、タートルの
  /// 「表示だけ」1タップ目（[_previewTopicOnly]）の両方から共有する
  /// （Step 3）。[fixedPrompt]モードでは選定不要（[_activePrompt]は既に
  /// 確定済み）。抽選対象が0件のときはfalseを返し、呼び出し元は何もしない
  /// （Ⅱランダムと同じ挙動）。
  Future<bool> _prepareActivePromptForNewAttempt() async {
    if (widget.fixedPrompt == null) {
      final prompt = await drawRandomQuestionPrompt();
      if (!mounted) return false;
      if (prompt == null) return false;
      _drawnPrompt = prompt;
      _sampleAnswer = prompt.sampleAnswer;
    }
    setState(() {
      _lastResult = null;
      chromeAiAwaitingPaste = false;
      chromeAiPendingSentPrompt = null;
      _chromeAiPendingKind = null;
    });
    return true;
  }

  @override
  Future<void> drawAndSpeak() async {
    final ready = await _prepareActivePromptForNewAttempt();
    if (!ready) return;
    await super.drawAndSpeak();
  }

  /// タートルモード1タップ目：問題文だけ表示し、読み上げはまだ始めない
  /// （Step 3）。抽選対象が0件のときは[_prepareActivePromptForNewAttempt]と
  /// 同じく黙って何もしない。
  Future<void> _previewTopicOnly() async {
    final ready = await _prepareActivePromptForNewAttempt();
    if (!ready) return;
    final topic = await pickTopic();
    if (!mounted) return;
    setState(() {
      drawnTopic = topic;
      _awaitingSpeakAfterPreview = true;
    });
  }

  /// タートルモード2タップ目：1タップ目で表示済みの[drawnTopic]をそのまま
  /// 読み上げる（表示済みの問題文を捨てない。抽選はやり直さない）（Step 3）。
  Future<void> _startSpeakingAfterPreview() async {
    final topic = drawnTopic;
    if (topic == null) return;
    setState(() => _awaitingSpeakAfterPreview = false);
    await speakDrawnTopic(topic);
  }

  /// idle時のタップ動線をラピッド／タートルで分岐する（Step 3・4）。
  /// - 表示済み（読み上げ待ち、[_awaitingSpeakAfterPreview]）：モード判定より
  ///   先に[_startSpeakingAfterPreview]を優先する。タートルで問題文を表示
  ///   した後にモードをラピッドへ切り替えても（Step 4の長押し）、表示済みの
  ///   問題文を捨てずそのまま読み上げるため（UX仕様）。
  /// - ラピッド：現行どおり[drawAndSpeak]（抽選＋読み上げを1タップで）。
  /// - タートル・未抽選：[_previewTopicOnly]（表示のみ）。
  /// idle以外（speaking/counting）は基底クラスの一時停止/再開・タイマー
  /// トグルをそのまま使う。
  @override
  Future<void> onButtonTap() async {
    if (buttonPhase != TopicSpeakerTimerPhase.idle) {
      await super.onButtonTap();
      return;
    }
    if (_awaitingSpeakAfterPreview && drawnTopic != null) {
      await _startSpeakingAfterPreview();
      return;
    }
    if (appSettings.layer4PromptRevealMode != Layer4PromptRevealMode.turtle) {
      await super.onButtonTap();
      return;
    }
    await _previewTopicOnly();
  }

  /// サイコロ／開始アイコンの長押し：ラピッド⇔タートルを切り替える
  /// （Step 4）。読み上げ中・カウントダウン中・採点中・AI貼り付け待ち
  /// （[isBusy]）は無効（[TopicSpeakerTimerButton]自体もphaseがidleの
  /// ときしか長押しを発火しないが、採点中はphaseがidleに戻っているため
  /// ここでも明示的にガードする）。
  void _toggleRevealMode() {
    if (isBusy) return;
    final next =
        appSettings.layer4PromptRevealMode == Layer4PromptRevealMode.rapid
        ? Layer4PromptRevealMode.turtle
        : Layer4PromptRevealMode.rapid;
    setState(() => appSettings.layer4PromptRevealMode = next);
    final lang = appSettings.language;
    final modeName =
        (next == Layer4PromptRevealMode.turtle
                ? 'レイヤーⅣ_モード_タートル'
                : 'レイヤーⅣ_モード_ラピッド')
            .tr(lang);
    _showMessage('レイヤーⅣ_モード_切替'.tr(lang).replaceFirst('{{mode}}', modeName));
  }

  /// 録音を停止・文字起こしして採点し、結果を保存する。
  /// 詳細は「例示」枠をタップ（最新1件）または長押し（一覧）で開く。
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
      final activePrompt = _activePrompt;
      final saved = SavedScoringResult(
        id: '${now.microsecondsSinceEpoch}_${_idRandom.nextInt(1 << 32)}',
        createdAt: now,
        result: result,
        questionPromptId: activePrompt?.id,
        questionPromptBody: activePrompt?.body,
      );
      await _storage.save(saved);
      unawaited(
        _persistScoreToPrompt(
          jsstScore: JsstScoringService.combinedReferenceLevel(result),
        ),
      );
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
        modelAnswer: eval.modelAnswer,
        modelAnswerRomaji: eval.modelAnswerRomaji,
        modelAnswerVi: eval.modelAnswerVi,
      );
      await _storage.update(updated);
      unawaited(
        _persistScoreToPrompt(
          hitScore: eval.hitStars,
          prepScore: eval.prepStars,
        ),
      );
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

  /// PREP・的中度の紙飛行機タップ。解答例の貼り付け待ち中は何もしない
  /// （用途違いの貼り付けを誤って走らせない。Step 3「AI往復の衝突」）。
  Future<void> _onSubmitPrepHitTap() async {
    if (_isSampleAnswerAwaitingPaste) return;
    _chromeAiPendingKind = _ChromeAiPendingKind.prepHit;
    await chromeAiOnSubmitTap(
      onSend: _sendToChromeAi,
      onPaste: _pasteAndSaveResult,
    );
  }

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
      // ランダムでは抽選済みの問題文も一緒に手放す（Step 4。[drawnTopic]と
      // 同じ「サイコロ待ちに戻す」扱い。[fixedPrompt]モードでは常にnullの
      // ままなので影響しない）。
      _drawnPrompt = null;
      _sampleAnswer = widget.fixedPrompt?.sampleAnswer ?? '';
      buttonPhase = TopicSpeakerTimerPhase.idle;
      _awaitingSpeakAfterPreview = false;
      _lastResult = null;
      chromeAiAwaitingPaste = false;
      chromeAiPendingResponseLanguage = 'ja';
      chromeAiPendingSentPrompt = null;
      _chromeAiPendingKind = null;
      hideResetUntilNextChange(_resetStateKey());
    });
  }

  /// カテゴリ変更でも表示中の問題文が消えるため（基底クラスが
  /// `drawnTopic = null`にする）、Ⅱランダムと同じ理由で抽選済み問題文
  /// （[_drawnPrompt]）・解答例の貼り付け待ちも一緒に解除する（Step 4）。
  void _onDrawSelectionChanged(QuestionPromptDrawSelection selection) {
    if (chromeAiAwaitingPaste) clearChromeAiPendingState();
    super.onDrawSelectionChanged(selection);
    if (!mounted) return;
    setState(() {
      _drawnPrompt = null;
      _sampleAnswer = '';
      _awaitingSpeakAfterPreview = false;
    });
  }

  /// 基底クラスは「15+60秒」以外へ切り替えたとき、シチュエーション選択中
  /// なら`selectedCategory`・[drawnTopic]を日常にリセットする。ランダムで
  /// 抽選済みの問題文（[_drawnPrompt]）も同じ条件で一緒に手放す（Step 4）。
  @override
  void onPresetTap(NormalTimerOption option) {
    final wasSituational =
        drawSelection.kind == QuestionPromptDrawKind.situational;
    super.onPresetTap(option);
    if (mounted) setState(() => _awaitingSpeakAfterPreview = false);
    if (widget.fixedPrompt == null &&
        wasSituational &&
        option != NormalTimerOption.prep15speaking60) {
      setState(() {
        _drawnPrompt = null;
        _sampleAnswer = '';
      });
    }
  }

  /// 「理由」枠＝解答例ボタン（Step 3）。Ⅱとまったく同じ能力
  /// （[Layer2SampleAnswerMixin.onSampleAnswerTap]：未取得→送信、
  /// 貼り付け待ち→貼り付け、取得済み→閲覧）。PREP・的中度が貼り付け待ち
  /// 中は何もしない（Step 3「AI往復の衝突」）。
  Future<void> _onSampleAnswerReasonTap() async {
    if (_isPrepHitAwaitingPaste) return;
    _chromeAiPendingKind = _ChromeAiPendingKind.sampleAnswer;
    await onSampleAnswerTap();
  }

  /// 取得済み時の長押し＝再取得。PREP・的中度が貼り付け待ち中は何もしない
  /// （理由は[_onSampleAnswerReasonTap]と同じ）。
  Future<void> _onSampleAnswerReasonLongPress() async {
    if (_isPrepHitAwaitingPaste) return;
    _chromeAiPendingKind = _ChromeAiPendingKind.sampleAnswer;
    await onSampleAnswerLongPress();
  }

  Future<void> _openHistory() async {
    await AppRoutes.openScoringHistory(context);
    // 一覧画面で削除された可能性があるため、戻ってきたら再読み込みする。
    await _loadSavedResults();
  }

  /// 「例示」枠タップ＝最新1件の採点結果詳細を開く（Step 7）。詳細画面自体は
  /// 削除機能を持たないが、[_openHistory]と同じく戻ってきたら念のため
  /// 再読み込みする（既存パターンを踏襲）。
  Future<void> _openLatestResult() async {
    await AppRoutes.openLatestScoringResult(context);
    await _loadSavedResults();
  }

  Future<void> _showAddChoice() =>
      showTopicAddChoiceFlow(context, initialCategory: selectedCategory);

  /// 「＋」長押し：タイマー〜採点結果確認までのステップを表示する。
  /// [fixedPrompt]モードでは、カテゴリ選択・サイコロ抽選のステップの代わりに、
  /// 開始ボタン・「Ⅴ」への遷移ステップを案内する。サイコロ／開始ボタンの
  /// 手順は現在のモード（[AppSettings.layer4PromptRevealMode]）に合わせて
  /// タートル用の2タップ手順に差し替え、いずれのモードでもモード切替
  /// （長押し）の案内を1行添える（Step 9）。
  void _showUsageHelp() {
    final lang = appSettings.language;
    final fixedPrompt = widget.fixedPrompt;
    final isTurtle =
        appSettings.layer4PromptRevealMode == Layer4PromptRevealMode.turtle;
    LayerHelpSheet.show(
      context,
      title: '操作方法'.tr(lang),
      lines: fixedPrompt != null
          ? [
              LayerHelpLine(text: 'レイヤーⅣ_使い方_タイマー'.tr(lang)),
              LayerHelpLine(
                text: (isTurtle ? 'レイヤーⅣ_問題文_使い方_開始_タートル' : 'レイヤーⅣ_問題文_使い方_開始')
                    .tr(lang),
                icon: Icons.play_circle_fill_rounded,
              ),
              LayerHelpLine(text: 'レイヤーⅣ_使い方_モード切替'.tr(lang)),
              LayerHelpLine(text: 'レイヤーⅣ_問題文_使い方_日本語回答'.tr(lang)),
              LayerHelpLine(text: 'レイヤーⅣ_問題文_使い方_解答例'.tr(lang)),
              LayerHelpLine(
                text: 'レイヤーⅣ_問題文_使い方_PREP的中度'.tr(lang),
                icon: Icons.send_rounded,
              ),
              LayerHelpLine(text: 'レイヤーⅣ_問題文_使い方_採点結果'.tr(lang)),
              LayerHelpLine(text: 'レイヤーⅣ_問題文_使い方_V'.tr(lang)),
            ]
          : [
              LayerHelpLine(text: 'レイヤーⅣ_使い方_タイマー'.tr(lang)),
              LayerHelpLine(text: 'レイヤーⅣ_使い方_カテゴリ'.tr(lang)),
              LayerHelpLine(
                text: (isTurtle ? 'レイヤーⅣ_使い方_サイコロ_タートル' : 'レイヤーⅣ_使い方_サイコロ').tr(
                  lang,
                ),
                icon: Icons.casino,
              ),
              LayerHelpLine(text: 'レイヤーⅣ_使い方_モード切替'.tr(lang)),
              LayerHelpLine(text: 'レイヤーⅣ_使い方_日本語回答'.tr(lang)),
              LayerHelpLine(text: 'レイヤーⅣ_使い方_解答例'.tr(lang)),
              LayerHelpLine(
                text: 'レイヤーⅣ_使い方_PREP的中度'.tr(lang),
                icon: Icons.send_rounded,
              ),
              LayerHelpLine(text: 'レイヤーⅣ_使い方_採点結果'.tr(lang)),
            ],
    );
  }

  /// 読み上げ・カウントダウン・録音・文字起こし・AI貼り付け待ちのいずれかが
  /// 進行中かどうか（[Layer4QuestionPromptDetailScreen]が上下スワイプでの
  /// 問題文切り替えを許可するかどうかの判定に使う。進行中の録音・AI待ちを
  /// 保存せず失わせないためのガード）。
  bool get isBusy =>
      buttonPhase != TopicSpeakerTimerPhase.idle ||
      _isEvaluating ||
      chromeAiAwaitingPaste;

  /// idleアイコン（Step 3）。タートルで表示待ち（[_awaitingSpeakAfterPreview]）
  /// のときだけ、抽選/開始アイコンをスピーカーに差し替える
  /// （[TopicSpeakerTimerButton]自体にはビジネスロジックを入れない方針）。
  IconData get _idleIcon {
    if (_awaitingSpeakAfterPreview) return Icons.volume_up;
    return widget.fixedPrompt != null
        ? Icons.play_circle_fill_rounded
        : Icons.casino;
  }

  /// idleアイコンの色（Step 3）。ラピッドのときだけ橙（[AppPalette.cardAccent]。
  /// [PrepStageRow]の点滅と同じ「橙＝ラピッド寄りの強調色」の使い方）に
  /// する。タートルは通常色（既定の[AppPalette.onAccent]）のまま。
  Color? _idleForegroundColor(AppPalette palette) =>
      appSettings.layer4PromptRevealMode == Layer4PromptRevealMode.rapid
      ? palette.cardAccent
      : null;

  // ── テスト専用フック ──────────────────────────────────────────────────
  // 実機のネイティブ録音・文字起こしは Flutter widget test 上で再現できない
  // ため、[Layer5ScreenState]と同じく、JSST採点直後の状態（[_lastResult]）
  // を経由せず直接与えるフックのみを用意する。

  @visibleForTesting
  SavedScoringResult? get debugLastResult => _lastResult;

  /// ランダムで抽選済みの問題文（Step 4）。抽選元が
  /// [QuestionPromptService]になっていることをテストで確認するためのフック。
  @visibleForTesting
  QuestionPrompt? get debugDrawnPrompt => _drawnPrompt;

  /// [fixedPrompt]モードの、採点結果の問題文への反映（[_persistScoreToPrompt]）
  /// を実際の録音・AI貼り付けを経由せず直接呼ぶ（テスト用）。
  @visibleForTesting
  Future<void> debugPersistScoreToPrompt({
    int? jsstScore,
    int? hitScore,
    int? prepScore,
  }) => _persistScoreToPrompt(
    jsstScore: jsstScore,
    hitScore: hitScore,
    prepScore: prepScore,
  );

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
    final fixedPrompt = widget.fixedPrompt;
    final activePrompt = _activePrompt;
    final hasSampleAnswer = _sampleAnswer.isNotEmpty;
    final showLayer5Badge =
        fixedPrompt != null &&
        widget.onGoToLayer5 != null &&
        (_lastResult?.hasAiEvaluation ?? false);
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
                  addTooltip: fixedPrompt != null ? '操作方法' : 'お題の取り込み',
                  selectedOption: timerController.option,
                  onPresetTap: onPresetTap,
                  // 既存の問題文で採点するモードのため、ここからの新規追加は
                  // 行わない（タップは無効。長押しの使い方シートのみ）。
                  onAddTap: fixedPrompt != null ? () {} : _showAddChoice,
                  onAddLongPress: _showUsageHelp,
                  addHintTapText: fixedPrompt != null ? null : 'お題の取り込み',
                  addHintLongPressText: '操作方法',
                ),
              ),
              const SizedBox(height: 4),
              // カテゴリは一覧のフィルタで絞り込めるため、[fixedPrompt]モードの
              // 詳細では表示せず、同じ枠に前後の問題文へ移動する▲▼ボタンを
              // 置く。
              fixedPrompt != null
                  ? QuestionPromptNavRow(
                      canGoPrevious: widget.canGoPrevious,
                      canGoNext: widget.canGoNext,
                      onPrevious: widget.onGoPrevious ?? () {},
                      onNext: widget.onGoNext ?? () {},
                    )
                  : ListenableBuilder(
                      listenable: timerController,
                      builder: (context, _) => QuestionPromptDrawSelectField(
                        selected: drawSelection,
                        showSituational: showSituationalInDrawSelect,
                        onChanged: _onDrawSelectionChanged,
                      ),
                    ),
              const SizedBox(height: 4),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DiceTopicCard(topic: _displayedTopic),
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
                    onLongPress: _toggleRevealMode,
                    size: 98,
                    idleIcon: _idleIcon,
                    idleTooltip: fixedPrompt != null ? '開始'.tr(lang) : null,
                    idleForegroundColor: _idleForegroundColor(palette),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // レイヤーⅢと異なり、PREPガイドは使わないため「結論」「理由」は
              // 非表示のまま、「例示」の枠だけ「＋」と同じ結果一覧導線に転用する。
              // 保存済み採点結果があるときだけ表示する。
              PrepLabelRow(
                // 「理由」枠＝解答例ボタン（Step 3・4）。「一覧から選ぶ」
                // （[fixedPrompt] != null）では常に表示（Ⅱ一覧詳細と同じ、
                // 未取得でも新規作成できる）。「ランダム」は抽選後
                // （[_drawnPrompt] != null）だけ表示する（Ⅱランダムと同じ、
                // 未抽選では問題文自体が無いため隠したまま）。
                showReason: activePrompt != null,
                // 未抽選のランダムでは、他レイヤーと同じ「理由」の予約席
                // （文字ラベル、ghost表示）のままにする（[reasonIcon]をnullに
                // しないと、Ⅲ等と同じ構成を前提にした既存テストの予約席
                // ラベル検出が壊れる）。
                reasonIcon: activePrompt == null
                    ? null
                    : (_isSampleAnswerAwaitingPaste
                          ? Icons.content_paste_go_rounded
                          : Icons.menu_book_rounded),
                reasonTooltip: activePrompt == null
                    ? null
                    : (_isSampleAnswerAwaitingPaste ? '貼り付け' : '解答例'),
                reasonShowBorder: false,
                reasonHorizontalPadding: 0,
                reasonActive: _isSampleAnswerAwaitingPaste || hasSampleAnswer,
                reasonActiveForeground: _isSampleAnswerAwaitingPaste
                    ? kPasteReadyColor
                    : null,
                onReasonTap: activePrompt != null
                    ? _onSampleAnswerReasonTap
                    : null,
                onReasonLongPress: activePrompt != null
                    ? _onSampleAnswerReasonLongPress
                    : null,
                // ダブルタップの機能ヒント（Ⅱと同型）。対象問題文が無い
                // （ランダム未抽選）ときはヒントも出さない。
                reasonHintTapText: activePrompt == null
                    ? null
                    : (_isSampleAnswerAwaitingPaste
                          ? '貼り付け'
                          : (hasSampleAnswer ? '解答例' : 'レイヤーⅡ_解答例_取得')),
                reasonHintLongPressText:
                    activePrompt != null &&
                        !_isSampleAnswerAwaitingPaste &&
                        hasSampleAnswer
                    ? 'レイヤーⅡ_解答例_再取得'
                    : null,
                showExample: _savedResults.isNotEmpty,
                exampleIcon: Icons.list_alt_rounded,
                exampleTooltip: '採点結果',
                exampleActive: _savedResults.isNotEmpty,
                // タップ＝最新1件の詳細、長押し＝一覧（Step 7）。
                onExampleTap: _openLatestResult,
                onExampleLongPress: _openHistory,
                exampleHintTapText: '採点結果_最新',
                exampleHintLongPressText: '採点結果_一覧',
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
                      showDiagnose: _showSendPrepHit || _isPrepHitAwaitingPaste,
                      languageCode: lang,
                      playing: isPlayingLastRecording,
                      playHasData: recordingService.lastRecordingPath != null,
                      diagnoseHighlighted:
                          _showSendPrepHit && !_isPrepHitAwaitingPaste,
                      diagnoseAwaitingPaste: _isPrepHitAwaitingPaste,
                      onPlay: _toggleLastRecordingPlayback,
                      onReset: resetAttempt,
                      onDiagnose:
                          !chromeAiActionInFlight &&
                              (_showSendPrepHit || _isPrepHitAwaitingPaste)
                          ? _onSubmitPrepHitTap
                          : null,
                      // AI評価（PREP・的中度）が届いたら、紙飛行機の代わりに
                      // 「Ⅴ」へ進むバッジを同じ枠に出す（一覧から選ぶモードのみ）。
                      diagnoseOverride: showLayer5Badge
                          ? LayerNumeralBadge(
                              layerIndex: 4,
                              onTap: widget.onGoToLayer5!,
                              tooltip: 'レイヤーⅤタイトル'.tr(lang),
                              hintTapText: 'レイヤーⅤタイトル'.tr(lang),
                            )
                          : null,
                      enableActionHints: true,
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
