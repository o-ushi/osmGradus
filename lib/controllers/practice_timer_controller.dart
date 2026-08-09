import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../models/practice_timer_models.dart';

/// osmWashabeの`PracticeController`のタイマー部分（`tickNormalModeTimer`/
/// `tickSituationModeTimer`/`startPreparationCountdown`/`enterSpeakingPhase`）
/// の移植。TTS読み上げ・バックグラウンドキープアライブ連携は含めない
/// （osmGradusにその基盤がないため、カウントダウンの仕組みのみを移植する）。
class PracticeTimerController extends ChangeNotifier {
  PracticeTimerController({
    this.onStarted,
    this.onSpeakingPhaseStart,
    this.onFinished,
    this.onPrepTick,
  }) {
    reset();
  }

  /// タイマーが停止状態から再生された瞬間に呼ばれる
  /// （PREP段階を「結論」から点滅し直すフックに使う）。
  final VoidCallback? onStarted;

  /// 「15+60秒」プリセットの発話フェーズに入った瞬間に呼ばれる
  /// （Layer IVの録音開始フックに使う）。
  final VoidCallback? onSpeakingPhaseStart;

  /// タイマーが完全に終了した瞬間に呼ばれる
  /// （Layer IVの録音停止・採点フックに使う）。
  final VoidCallback? onFinished;

  /// 「15+60秒」プリセットの準備フェーズ（15秒）中、1秒経過するたびに
  /// （残り秒数を減らす直前に）呼ばれる。osmWashabeの秒読みビープ・
  /// バイブレーションのフック。音・振動の再生自体はSystemSound/
  /// HapticFeedbackへの依存を持たない呼び出し側（レイヤー画面）に委ねる
  /// （このコントローラをテスト可能なまま保つため）。
  final VoidCallback? onPrepTick;

  NormalTimerOption option = NormalTimerOption.sec45;
  int remainingSeconds = 45;
  bool isRunning = false;
  TimerPhase phase = TimerPhase.preparation;

  DateTime? _deadline;
  Timer? _ticker;

  /// 「15+60秒」プリセットのみ準備→発話の二相タイマーになる。
  bool get usesTwoPhaseTimer => option == NormalTimerOption.prep15speaking60;

  bool get isFinished {
    if (usesTwoPhaseTimer) {
      return phase == TimerPhase.speaking && remainingSeconds == 0;
    }
    return remainingSeconds == 0;
  }

  void setOption(NormalTimerOption value) {
    if (option == value) return;
    option = value;
    reset();
  }

  void reset() {
    _stopTicking();
    isRunning = false;
    _deadline = null;
    phase = TimerPhase.preparation;
    remainingSeconds = switch (option) {
      NormalTimerOption.sec45 => 45,
      NormalTimerOption.sec60 => 60,
      NormalTimerOption.prep15speaking60 =>
        TimerPhase.preparation.durationSeconds,
    };
    notifyListeners();
  }

  void toggle() {
    if (isRunning) {
      _stopTicking();
      isRunning = false;
      _deadline = null;
      notifyListeners();
      return;
    }
    if (isFinished || remainingSeconds <= 0) return;
    isRunning = true;
    _deadline = clock.now().add(Duration(seconds: remainingSeconds));
    // 直前のフェーズの周期タイマーが残っていた場合に備え、必ず作り直してから
    // 開始する。次のtickがちょうど1秒後に来ることを保証するため
    // （osmWashabeの`disposeTicking(); startTicking();`と同じ狙い）。
    _stopTicking();
    _startTicking();
    notifyListeners();
    onStarted?.call();
  }

  void _startTicking() {
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _stopTicking() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _tick() {
    if (!isRunning) return;
    final deadline = _deadline;
    if (deadline == null) return;
    final now = clock.now();

    // 「準備15秒カウントダウンが15ではなく13から始まる」バグの原因は、通常の
    // ティックのたびにdeadlineとの差分から残り秒数を再計算していたこと
    // （Timer.periodicの1回目の発火が理論上の1秒ちょうどより少し遅れただけで、
    // 差分計算が2秒分減った値を返してしまう）。osmWashabeでも同じ症状が出て、
    // 通常ティックは必ず1秒ずつ減らすだけにし、deadline判定は「期限を過ぎて
    // いないか」の検知だけに使うよう直した経緯があるため、ここも同じ方式にする。
    // ちょうどdeadline上でtickが発火する場合（fakeAsyncのテスト等）は
    // 「期限を過ぎた」扱いにせず、通常の1秒分の減算（秒読み音を含む）を
    // 行う（osmWashabeの`isAfter`と同じ、厳密に「過ぎている」場合のみ
    // 即座に0にする判定）。
    if (now.isAfter(deadline)) {
      remainingSeconds = 0;
    } else if (remainingSeconds > 0) {
      // 準備フェーズ中だけ、減らす直前に秒読み音・バイブレーションを鳴らす
      // （osmWashabeの`_alert.playTick()`と同じタイミング）。
      if (usesTwoPhaseTimer && phase == TimerPhase.preparation) {
        onPrepTick?.call();
      }
      remainingSeconds -= 1;
    }

    if (remainingSeconds > 0) {
      notifyListeners();
      return;
    }

    if (usesTwoPhaseTimer && phase == TimerPhase.preparation) {
      _enterSpeakingPhase();
      return;
    }

    _stopTicking();
    isRunning = false;
    _deadline = null;
    notifyListeners();
    onFinished?.call();
  }

  void _enterSpeakingPhase() {
    phase = TimerPhase.speaking;
    remainingSeconds = TimerPhase.speaking.durationSeconds;
    _deadline = clock.now().add(Duration(seconds: remainingSeconds));
    // フェーズが切り替わる瞬間も周期タイマーを作り直し、発話60秒の最初の
    // ティックがちょうど1秒後に来るようにそろえる。
    _stopTicking();
    _startTicking();
    notifyListeners();
    onSpeakingPhaseStart?.call();
  }

  @override
  void dispose() {
    _stopTicking();
    super.dispose();
  }
}
