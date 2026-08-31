import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/practice_timer_controller.dart';
import '../../controllers/prep_stage_controller.dart';
import '../../main.dart' show appSettings, topicSpeechReader, ttsSettings;
import '../../models/drawn_topic.dart';
import '../../models/practice_timer_models.dart';
import '../../models/topic_category.dart';
import '../../services/alarm_sound_service.dart';
import '../../services/recording_stt_service.dart';
import '../../services/screen_wake_service.dart';
import '../../services/tick_beep_player.dart';
import '../../services/topic_service.dart';
import '../../widgets/topic_speaker_timer_button.dart';
import '../../widgets/speech_processing_consent_dialog.dart';

/// レイヤーⅢ・Ⅳで共通する「お題を引く→TTSで読み上げる→カウントダウン
/// する」の状態機械（サイコロ→スピーカー→カウントダウンのボタン状態、
/// シチュエーションの15+60秒専用フィルタ、録音開始タイミング、タイマー
/// 完了時のアラーム再生）をまとめた基底State。2レイヤーでほぼ同一実装
/// だった部分をここに集約し、レイヤーごとに異なる部分（タイマー完了時に
/// 採点するか、再生/リセットボタンの見せ方、PREPガイドを使うかなど）
/// だけをサブクラス側に残す。レイヤーⅤは録音フローが異なるため独立実装。
abstract class PracticeLayerScreenState<T extends StatefulWidget>
    extends State<T> {
  final topicService = TopicService();
  final recordingService = RecordingSttService();

  late final prepStageController = PrepStageController();
  late final timerController = PracticeTimerController(
    onStarted: handleTimerStarted,
    onSpeakingPhaseStart: handleSpeakingPhaseStart,
    onFinished: onTimerFinished,
    onPrepTick: _playPrepTick,
  );

  TopicCategory selectedCategory = TopicCategory.general;
  DrawnTopic? drawnTopic;
  TopicSpeakerTimerPhase buttonPhase = TopicSpeakerTimerPhase.idle;

  @override
  void initState() {
    super.initState();
    // カウントダウン中（準備・発話どちらのフェーズも[isRunning]がtrueのまま
    // 続く）は画面を点灯し続ける。読み上げ中の分は[drawAndSpeak]側で
    // 別の理由タグとして管理する（[ScreenWakeService]参照）。
    timerController.addListener(_syncWakeWithTimer);
    // レイヤーⅢ・Ⅳは[MainShell]に一度生成されたら破棄されずキャッシュ
    // され続けるため、設定画面で言語を変えて戻ってきただけでは再構築されず
    // 表示が古い言語のままになる。appSettingsの変更を直接購読し、その場で
    // 再描画することで、次に開いたときには反映済みにする。
    appSettings.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() => setState(() {});

  void _syncWakeWithTimer() {
    if (timerController.isRunning) {
      unawaited(ScreenWakeService.instance.acquire('countdownTimer'));
    } else {
      unawaited(ScreenWakeService.instance.release('countdownTimer'));
    }
  }

  /// 発話フェーズでマイク録音するか。レイヤーⅢは録音結果を使わないため
  /// false（同意ダイアログやSTTの無駄を避ける）。Ⅳは採点のため true。
  bool get enablesRecording => true;

  /// PREP（結論→理由→例示）ガイドを進めるか。レイヤーⅢのみ true。
  /// falseのときコントローラは動かさず、空回りを避ける。
  bool get enablesPrepGuide => false;

  /// タイマーが0になった瞬間の処理。レイヤーごとに実装が異なる
  /// （Ⅲ: アラームのみ、Ⅳ: 採点して結果画面を開く）。アラーム再生・待機状態
  /// への復帰は[playAlarmThenReturnToIdle]が担うので、必要ならここから呼ぶ。
  void onTimerFinished();

  /// 読み上げ・アラーム・カウントダウンを即座に中止し、サイコロボタンの
  /// 初期状態に戻す（「リセット」ボタンと同じ処理）。[MainShell]がレイヤーを
  /// 切り替える直前に、非表示になるレイヤーに対して呼び出す
  /// （読み上げ中・カウントダウン中のまま裏に回って動き続けないようにするため）。
  Future<void> resetAttempt();

  /// シチュエーションはosmWashabeと同じく「15+60秒」モード専用。分野は
  /// その他（[TopicCategory.general]）／シチュエーションの2つのみ
  /// （`question-prompt-tabs.md` Step 3、旧日常／ビジネスの3分類UIは廃止）。
  List<TopicCategory> get availableCategories =>
      timerController.usesTwoPhaseTimer
      ? const [TopicCategory.general, TopicCategory.situational]
      : const [TopicCategory.general];

  /// 読み上げ中・カウントダウン中にレイヤー切替・分野変更・プリセット変更が
  /// 起きたとき、裏で動き続けないよう「リセット」ボタンと同じ処理を挟む
  /// 共通ガード。アイドル中は何もしない。
  void _resetIfActive() {
    if (buttonPhase != TopicSpeakerTimerPhase.idle) {
      unawaited(resetAttempt());
    }
  }

  void onPresetTap(NormalTimerOption option) {
    // timerController.setOption自体はタイマーの秒数を静かに作り直すだけで、
    // TTS・録音・ボタン表示は止めてくれないため、先にリセットを挟む。
    _resetIfActive();
    timerController.setOption(option);
    // 45/60秒モードへ切り替えたとき、シチュエーションが選ばれていたら
    // osmWashabeと同じくリセットする（他のモードでは選べないため）。
    if (option != NormalTimerOption.prep15speaking60 &&
        selectedCategory == TopicCategory.situational) {
      setState(() {
        selectedCategory = TopicCategory.general;
        drawnTopic = null;
      });
    }
  }

  /// 分野セレクタの変更。レイヤーⅢ・Ⅳの`CategorySelectField.onChanged`に
  /// そのまま渡す共通実装。
  void onCategoryChanged(TopicCategory category) {
    _resetIfActive();
    setState(() {
      selectedCategory = category;
      drawnTopic = null;
    });
  }

  Future<void> onButtonTap() async {
    switch (buttonPhase) {
      case TopicSpeakerTimerPhase.idle:
        await drawAndSpeak();
      case TopicSpeakerTimerPhase.speaking:
        if (topicSpeechReader.isPaused) {
          topicSpeechReader.resume();
        } else {
          topicSpeechReader.pause();
        }
      case TopicSpeakerTimerPhase.counting:
        timerController.toggle();
    }
  }

  /// 実際にどのお題を読み上げるかを決める。既定はサイコロ抽選
  /// （[TopicService.drawRandom]）。レイヤーⅣの「一覧から選ぶ」経由
  /// （特定の[QuestionPrompt]に固定された詳細画面）はこれをオーバーライドし、
  /// 抽選をスキップして固定の問題文をそのまま返す
  /// （録音・タイマー・採点のエンジン自体は共通のまま再利用するため）。
  Future<DrawnTopic> pickTopic() => topicService.drawRandom(selectedCategory);

  Future<void> drawAndSpeak() async {
    final topic = await pickTopic();
    if (!mounted) return;
    setState(() => drawnTopic = topic);
    await speakDrawnTopic(topic);
  }

  /// [drawnTopic]として既に確定している問題文を読み上げ、カウントダウンへ
  /// つなげる（[drawAndSpeak]の「抽選」より後の部分）。レイヤーⅣのタートル
  /// モード（問題文表示とこの読み上げ開始を別タップに分ける）が、抽選
  /// （[pickTopic]）を経由せず表示済みの[drawnTopic]だけを渡して直接呼べる
  /// よう切り出している。
  Future<void> speakDrawnTopic(DrawnTopic topic) async {
    if (!mounted) return;
    topicSpeechReader.clearGenderLock();
    // タイマー開始（onStarted）を待たず、読み上げを始める瞬間に
    // 「結論」から点滅し直す（PREPガイド利用時のみ）。
    if (enablesPrepGuide) prepStageController.start();
    setState(() => buttonPhase = TopicSpeakerTimerPhase.speaking);

    // 「15+60秒」は準備フェーズの案内込みで読み上げる（osmWashabeと同じ文言）。
    final text = timerController.usesTwoPhaseTimer
        ? '${topic.text}。15秒間考えてください。'
        : topic.text;

    // お題読み上げ中は画面を点灯し続ける。二相タイマーではonFinish内で
    // カウントダウンが始まり（'countdownTimer'理由が別途成立するため）、
    // この読み上げ分の理由をここで外してもWakelockはONのまま維持される。
    unawaited(ScreenWakeService.instance.acquire('topicSpeech'));
    try {
      await topicSpeechReader.speak(
        text: text,
        onFinish: () async {
          if (!mounted) return;
          // 録音しないレイヤー（Ⅲ）では音声認識同意を出さない。
          if (enablesRecording) {
            final consented = await SpeechProcessingConsentDialog.ensure(
              context,
              appSettings.language,
            );
            if (!consented || !mounted) {
              setState(() {
                buttonPhase = TopicSpeakerTimerPhase.idle;
                if (enablesPrepGuide) prepStageController.reset();
              });
              return;
            }
          }
          setState(() => buttonPhase = TopicSpeakerTimerPhase.counting);
          if (timerController.usesTwoPhaseTimer) {
            // osmWashabeのpreparationBreathDelay（読み上げ後の一拍）に相当。
            await Future.delayed(const Duration(milliseconds: 1000));
            if (!mounted) return;
          }
          timerController.toggle();
        },
      );
    } finally {
      unawaited(ScreenWakeService.instance.release('topicSpeech'));
    }
  }

  /// osmWashabeの`_phaseTransitionSoundId`（iOSのシステムサウンドID）と同じ
  /// 値。`AlarmSound.swift`/`AlarmSound.kt`の`play()`は数値文字列を渡すと
  /// （iOSのみ）`AudioServicesPlaySystemSound`で即座に鳴らす、
  /// AVAudioSessionを介さない軽量な経路になっている。
  static const _phaseTransitionSoundId = '1057';

  /// カスタムアラーム音が未選択のときの既定音（osmWashabeの
  /// カタログ先頭「三連音」と同じID）。
  static const _defaultAlarmSoundId = '1307';

  void handleTimerStarted() {
    if (enablesPrepGuide) prepStageController.start();
    // 単発（45/60秒）はタイマー開始＝発話フェーズ開始なので、そのまま録音を始める。
    // 「15+60秒」は準備フェーズ中は録音しない（onSpeakingPhaseStartで開始する）。
    if (!timerController.usesTwoPhaseTimer) {
      if (enablesRecording) {
        unawaited(recordingService.startRecording());
      }
    } else if (!Platform.isIOS) {
      // 秒読みビープの初回再生が音源読み込み待ちで遅れないよう、
      // カウントダウンが始まる前に読み込んでおく（Android。iOSは
      // システムサウンドIDを使うため読み込み不要）。
      unawaited(TickBeepPlayer.instance.warmUp());
    }
  }

  /// 準備15秒カウントダウン中、1秒経過するごとに鳴らす秒読み音・バイブレーション
  /// （osmWashabeの`_alert.playTick()`相当）。
  void _playPrepTick() {
    unawaited(_playShortSignal());
    unawaited(HapticFeedback.lightImpact());
  }

  /// 録音中（iOSは`.playAndRecord`カテゴリ）でも確実に鳴る短い合図。
  /// iOSはosmWashabeと同じくシステムサウンドID（AVAudioSessionを介さず、
  /// マナースイッチ以外の影響を受けにくい）、Androidは合成ビープを使う。
  Future<void> _playShortSignal() {
    if (Platform.isIOS) {
      return AlarmSoundService.play(_phaseTransitionSoundId);
    }
    return TickBeepPlayer.instance.play();
  }

  // 録音を始めた直後は（iOS実機で確認済み）AVAudioSessionの構成次第でTTSの
  // 発話が完全に無音になることがあったため、iOSの録音カテゴリを
  // `.playAndRecord`に変更し、録音中でも再生できるようにした
  // （ios/Runner/SpeechCapture.swift参照）。それでも録音開始とTTSが同時に
  // オーディオセッションへ触るのは避けたいので、録音開始を待ってから
  // TTSを鳴らす順序自体は維持する（TTS自体はブロックしないようunawaited）。
  Future<void> handleSpeakingPhaseStart() async {
    // 準備→発話の切り替わりを示す合図（osmWashabeの`playPhaseTransition()`
    // 相当）。TTSの「それでは、答えてください」が鳴るより前に、切り替わった
    // ことが即座に分かるようにする。
    unawaited(_playShortSignal());
    unawaited(HapticFeedback.mediumImpact());
    if (enablesRecording) {
      await recordingService.startRecording();
    }
    unawaited(topicSpeechReader.speak(text: 'それでは、答えてください。'));
  }

  /// カウントダウン終了時にアラームを鳴らし、サイコロ表示・タイマー初期値へ戻す。
  Future<void> playAlarmThenReturnToIdle() async {
    timerController.reset();
    if (enablesPrepGuide) prepStageController.reset();
    if (mounted) setState(() => buttonPhase = TopicSpeakerTimerPhase.idle);

    unawaited(HapticFeedback.heavyImpact());
    final sound = ttsSettings.alarmSound;
    if (sound.isEmpty) {
      if (Platform.isIOS) {
        await AlarmSoundService.play(_defaultAlarmSoundId);
      } else {
        await TickBeepPlayer.instance.play();
      }
      await Future.delayed(const Duration(milliseconds: 800));
    } else {
      await AlarmSoundService.play(sound);
      await Future.delayed(const Duration(milliseconds: 1500));
    }
  }

  @override
  void dispose() {
    appSettings.removeListener(_onSettingsChanged);
    timerController.removeListener(_syncWakeWithTimer);
    // 画面が破棄される瞬間に読み上げ・カウントダウンの途中だった場合、
    // 画面点灯の理由が残ったままにならないようの安全策。
    unawaited(ScreenWakeService.instance.release('topicSpeech'));
    unawaited(ScreenWakeService.instance.release('countdownTimer'));
    timerController.dispose();
    prepStageController.dispose();
    recordingService.dispose();
    super.dispose();
  }
}
