/// レイヤーⅠ単語テストの回答入力方式。
enum VocabAnswerMode {
  /// マイク録音＋音声認識（STT）。
  voice,

  /// キーボード入力（STTを経由せずテキストをそのままChrome AIへ渡す）。
  keyboard,
}
