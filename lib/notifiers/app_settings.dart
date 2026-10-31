import 'package:flutter/foundation.dart';

import '../models/layer4_prompt_reveal_mode.dart';
import '../models/long_article_word_selection_mode.dart';
import '../models/recording_mode.dart';
import '../models/vocab_answer_mode.dart';
import '../services/app_preferences.dart';

/// 表示言語の変更をアプリ全体へ通知する。
class AppSettings extends ChangeNotifier {
  AppSettings(this._prefs);

  final AppPreferences _prefs;

  String get language => _prefs.language;

  set language(String value) {
    if (_prefs.language == value) return;
    _prefs.language = value;
    notifyListeners();
  }

  RecordingMode get layer5RecordingMode => _prefs.layer5RecordingMode;

  set layer5RecordingMode(RecordingMode value) {
    if (_prefs.layer5RecordingMode == value) return;
    _prefs.layer5RecordingMode = value;
    notifyListeners();
  }

  /// レイヤーⅠ単語テストの録音モード（断続/半連続/連続）。
  RecordingMode get vocabRecordingMode => _prefs.vocabRecordingMode;

  set vocabRecordingMode(RecordingMode value) {
    if (_prefs.vocabRecordingMode == value) return;
    _prefs.vocabRecordingMode = value;
    notifyListeners();
  }

  /// 起動時のスタートアップ（案内）画面を出すか。
  bool get showStartupScreen => _prefs.showStartupScreen;

  /// OFFにするときは使い方画面も一緒にOFFにする（不変条件：使い方は
  /// スタートアップがONのときだけON。スタートアップだけ再度ONにしても
  /// 使い方は自動では戻さない）。
  set showStartupScreen(bool value) {
    final usageShouldTurnOff = !value && _prefs.showUsageScreen;
    if (_prefs.showStartupScreen == value && !usageShouldTurnOff) return;
    _prefs.showStartupScreen = value;
    if (usageShouldTurnOff) {
      _prefs.showUsageScreen = false;
    }
    notifyListeners();
  }

  /// スタートアップの「はじめる」後に使い方画面を出すか。
  bool get showUsageScreen => _prefs.showUsageScreen;

  set showUsageScreen(bool value) {
    if (_prefs.showUsageScreen == value) return;
    _prefs.showUsageScreen = value;
    notifyListeners();
  }

  /// レイヤーⅠの単語テスト／単語帳に標準JLPT語彙（各20語）を含めるか。
  bool get includeDefaultVocabulary => _prefs.includeDefaultVocabulary;

  set includeDefaultVocabulary(bool value) {
    if (_prefs.includeDefaultVocabulary == value) return;
    _prefs.includeDefaultVocabulary = value;
    notifyListeners();
  }

  /// レイヤーⅠ単語テストの回答入力方式（音声／キーボード）。
  VocabAnswerMode get vocabAnswerMode => _prefs.vocabAnswerMode;

  set vocabAnswerMode(VocabAnswerMode value) {
    if (_prefs.vocabAnswerMode == value) return;
    _prefs.vocabAnswerMode = value;
    notifyListeners();
  }

  /// レイヤーⅠ単語テストの回答言語のユーザー選択（未選択ならnull）。
  String? get vocabAnswerLanguageCode => _prefs.vocabAnswerLanguageCode;

  set vocabAnswerLanguageCode(String? value) {
    if (_prefs.vocabAnswerLanguageCode == value) return;
    _prefs.vocabAnswerLanguageCode = value;
    notifyListeners();
  }

  /// 長文読解の長押し＋ドラッグ単語選択のヒットテスト単位。
  LongArticleWordSelectionMode get longArticleWordSelectionMode =>
      _prefs.longArticleWordSelectionMode;

  set longArticleWordSelectionMode(LongArticleWordSelectionMode value) {
    if (_prefs.longArticleWordSelectionMode == value) return;
    _prefs.longArticleWordSelectionMode = value;
    notifyListeners();
  }

  /// ダブルタップの機能ヒント（Step 7）を、時間ではなく次のアクションが
  /// 入るまで表示し続けるか。
  bool get buttonHintPersistUntilNextAction =>
      _prefs.buttonHintPersistUntilNextAction;

  set buttonHintPersistUntilNextAction(bool value) {
    if (_prefs.buttonHintPersistUntilNextAction == value) return;
    _prefs.buttonHintPersistUntilNextAction = value;
    notifyListeners();
  }

  /// [buttonHintPersistUntilNextAction]がOFFのときの自動消去までの秒数。
  int get buttonHintDisplaySeconds => _prefs.buttonHintDisplaySeconds;

  set buttonHintDisplaySeconds(int value) {
    if (_prefs.buttonHintDisplaySeconds == value) return;
    _prefs.buttonHintDisplaySeconds = value;
    notifyListeners();
  }

  /// レイヤーⅣのお題表示モード（ラピッド/タートル）。サイコロ長押しで切替。
  Layer4PromptRevealMode get layer4PromptRevealMode =>
      _prefs.layer4PromptRevealMode;

  set layer4PromptRevealMode(Layer4PromptRevealMode value) {
    if (_prefs.layer4PromptRevealMode == value) return;
    _prefs.layer4PromptRevealMode = value;
    notifyListeners();
  }

  void refresh() => notifyListeners();
}
