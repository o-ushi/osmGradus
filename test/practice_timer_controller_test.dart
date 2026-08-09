import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osm_gradus/controllers/practice_timer_controller.dart';
import 'package:osm_gradus/models/practice_timer_models.dart';

void main() {
  test('45秒プリセットの初期値は45で、開始すると1秒ごとに減っていく', () {
    fakeAsync((async) {
      final controller = PracticeTimerController();
      expect(controller.option, NormalTimerOption.sec45);
      expect(controller.remainingSeconds, 45);

      controller.toggle();
      expect(controller.isRunning, isTrue);

      async.elapse(const Duration(seconds: 3));
      expect(controller.remainingSeconds, 42);

      controller.dispose();
    });
  });

  test('60秒プリセットに切り替えると即座にremainingSecondsが60になる', () {
    final controller = PracticeTimerController();
    controller.setOption(NormalTimerOption.sec60);
    expect(controller.remainingSeconds, 60);
    expect(controller.isRunning, isFalse);
    controller.dispose();
  });

  test('45/60秒プリセットのタイマーが0になるとonFinishedが呼ばれ、isFinishedがtrueになる', () {
    fakeAsync((async) {
      var finishedCount = 0;
      final controller = PracticeTimerController(
        onFinished: () => finishedCount++,
      );
      controller.toggle();
      async.elapse(const Duration(seconds: 45));

      expect(controller.remainingSeconds, 0);
      expect(controller.isFinished, isTrue);
      expect(controller.isRunning, isFalse);
      expect(finishedCount, 1);

      controller.dispose();
    });
  });

  test('「15+60秒」は準備15秒→発話60秒の二相タイマーになり、準備終了でonSpeakingPhaseStartが呼ばれる', () {
    fakeAsync((async) {
      var speakingStarted = false;
      final controller = PracticeTimerController(
        onSpeakingPhaseStart: () => speakingStarted = true,
      );
      controller.setOption(NormalTimerOption.prep15speaking60);
      expect(controller.usesTwoPhaseTimer, isTrue);
      expect(controller.phase, TimerPhase.preparation);
      expect(controller.remainingSeconds, 15);

      controller.toggle();
      async.elapse(const Duration(seconds: 15));

      expect(speakingStarted, isTrue);
      expect(controller.phase, TimerPhase.speaking);
      expect(controller.remainingSeconds, 60);
      expect(controller.isRunning, isTrue);
      expect(controller.isFinished, isFalse);

      controller.dispose();
    });
  });

  test('「15+60秒」は発話フェーズが0になって初めてisFinishedになる', () {
    fakeAsync((async) {
      final controller = PracticeTimerController();
      controller.setOption(NormalTimerOption.prep15speaking60);
      controller.toggle();
      async.elapse(const Duration(seconds: 15 + 60));

      expect(controller.phase, TimerPhase.speaking);
      expect(controller.remainingSeconds, 0);
      expect(controller.isFinished, isTrue);

      controller.dispose();
    });
  });

  test(
    '「15+60秒」の準備15秒は必ず15→14→…→1の15回だけonPrepTickが呼ばれ、'
    '発話フェーズ中は呼ばれない（準備カウントダウンが15ではなく13から'
    '始まる回帰を防ぐ）',
    () {
      fakeAsync((async) {
        var tickCount = 0;
        final controller = PracticeTimerController(
          onPrepTick: () => tickCount++,
        );
        controller.setOption(NormalTimerOption.prep15speaking60);
        controller.toggle();

        async.elapse(const Duration(seconds: 15));
        expect(tickCount, 15);
        expect(controller.phase, TimerPhase.speaking);
        expect(controller.remainingSeconds, 60);

        // 発話フェーズ中は秒読み音を鳴らさない。
        async.elapse(const Duration(seconds: 10));
        expect(tickCount, 15);

        controller.dispose();
      });
    },
  );

  test('45秒プリセット（単発モード）ではonPrepTickは呼ばれない', () {
    fakeAsync((async) {
      var tickCount = 0;
      final controller = PracticeTimerController(onPrepTick: () => tickCount++);
      controller.toggle();
      async.elapse(const Duration(seconds: 45));

      expect(tickCount, 0);
      expect(controller.isFinished, isTrue);

      controller.dispose();
    });
  });

  test('タイマーを開始するたびにonStartedが呼ばれる（PREP段階を結論からやり直すフック）', () {
    fakeAsync((async) {
      var startedCount = 0;
      final controller = PracticeTimerController(
        onStarted: () => startedCount++,
      );
      controller.toggle(); // 開始
      expect(startedCount, 1);
      controller.toggle(); // 一時停止（onStartedは呼ばれない）
      expect(startedCount, 1);
      controller.toggle(); // 再開
      expect(startedCount, 2);

      controller.dispose();
    });
  });

  test('reset()は現在のプリセットの初期値に戻し、タイマーを停止する', () {
    fakeAsync((async) {
      final controller = PracticeTimerController();
      controller.toggle();
      async.elapse(const Duration(seconds: 10));
      expect(controller.remainingSeconds, 35);

      controller.reset();
      expect(controller.remainingSeconds, 45);
      expect(controller.isRunning, isFalse);

      controller.dispose();
    });
  });
}
