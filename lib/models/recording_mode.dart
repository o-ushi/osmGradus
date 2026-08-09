/// 録音モード。断続→半連続→連続の順に自動化の度合いが上がる。
/// レイヤーⅤ（発音チェック）とレイヤーⅠ（単語テスト）の両方で使う共通モデル。
enum RecordingMode {
  /// 断続：マイクをタップするまで録音を始めない。停止後は文字起こし結果を
  /// 表示してサイコロに戻り、次の問題へ進むには改めてサイコロをタップする。
  intermittent,

  /// 半連続：サイコロタップと同時に録音まで自動的に始まる。停止後の挙動は
  /// 断続と同じく、結果を表示してサイコロに戻る。
  semiContinuous,

  /// 連続：サイコロタップ（1問目）または停止後に自動表示される次の問題
  /// （2問目以降）と同時に、録音まで自動的に始まる。結果は一切表示せず
  /// そのまま10問目まで進み続ける。
  continuous,
}

extension RecordingModeX on RecordingMode {
  /// トグルボタン用：断続→半連続→連続→断続…の順で次のモードへ進める。
  RecordingMode get next => switch (this) {
    RecordingMode.intermittent => RecordingMode.semiContinuous,
    RecordingMode.semiContinuous => RecordingMode.continuous,
    RecordingMode.continuous => RecordingMode.intermittent,
  };

  /// サイコロタップ（＝問題が表示された瞬間）に録音を自動で始めるか。
  /// 断続だけがfalse（マイクをタップするまで始まらない）。
  bool get autoStartsRecording => this != RecordingMode.intermittent;

  /// マイク停止後、結果を見せずサイコロを経由せず自動的に次の問題へ
  /// 進めるか。連続のときだけtrue。
  bool get autoAdvancesQuestions => this == RecordingMode.continuous;
}
