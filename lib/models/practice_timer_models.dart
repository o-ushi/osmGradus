// osmWashabeの`practice_models.dart`（NormalTimerOption/SituationTimerPhase）の移植。
// TTS読み上げ関連のプロパティは持たない（osmGradusにTTS基盤がないため）。

/// スピーチ練習のタイマープリセット。
enum NormalTimerOption {
  sec45,
  sec60,
  prep15speaking60;

  String get label => switch (this) {
    NormalTimerOption.sec45 => '45秒',
    NormalTimerOption.sec60 => '60秒',
    NormalTimerOption.prep15speaking60 => '15+60秒',
  };
}

/// 「15+60秒」プリセットの二相タイマーのフェーズ。
enum TimerPhase {
  preparation('準備', 15),
  speaking('発話', 60);

  const TimerPhase(this.label, this.durationSeconds);
  final String label;
  final int durationSeconds;
}
