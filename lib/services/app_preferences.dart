import 'package:shared_preferences/shared_preferences.dart';

import '../models/long_article_word_selection_mode.dart';
import '../models/recording_mode.dart';
import '../models/vocab_answer_mode.dart';

/// アプリ共通の永続化設定（言語など）。
class AppPreferences {
  AppPreferences(this._prefs);

  static const languageKey = 'osmGradus.language';
  static const layer5RecordingModeKey = 'osmGradus.layer5.recordingMode';
  static const vocabRecordingModeKey = 'osmGradus.layer1.vocabRecordingMode';
  static const showStartupScreenKey = 'osmGradus.showStartupScreen';
  static const includeDefaultVocabularyKey =
      'osmGradus.includeDefaultVocabulary';
  static const vocabAnswerModeKey = 'osmGradus.layer1.vocabAnswerMode';
  static const vocabAnswerLanguageCodeKey =
      'osmGradus.layer1.vocabAnswerLanguageCode';
  static const longArticleWordSelectionModeKey =
      'osmGradus.longArticle.wordSelectionMode';
  static const buttonHintPersistUntilNextActionKey =
      'osmGradus.buttonHint.persistUntilNextAction';
  static const buttonHintDisplaySecondsKey =
      'osmGradus.buttonHint.displaySeconds';
  static const defaultLanguage = 'vi';

  /// ダブルタップの機能ヒント（Step 7）の既定表示期間・選択肢（秒）。
  static const defaultButtonHintDisplaySeconds = 3;
  static const buttonHintDisplaySecondsOptions = [2, 3, 5, 8];

  final SharedPreferences _prefs;

  static Future<AppPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppPreferences(prefs);
  }

  String get language => _prefs.getString(languageKey) ?? defaultLanguage;

  set language(String value) => _prefs.setString(languageKey, value);

  /// レイヤーⅤの録音モード（断続/半連続/連続）。既定は断続。
  RecordingMode get layer5RecordingMode {
    final raw = _prefs.getString(layer5RecordingModeKey);
    return RecordingMode.values.firstWhere(
      (mode) => mode.name == raw,
      orElse: () => RecordingMode.intermittent,
    );
  }

  set layer5RecordingMode(RecordingMode value) =>
      _prefs.setString(layer5RecordingModeKey, value.name);

  /// レイヤーⅠ単語テストの録音モード（断続/半連続/連続）。既定は断続。
  /// レイヤーⅤとは別に独立して保持する（両者を切り替えても影響しない）。
  RecordingMode get vocabRecordingMode {
    final raw = _prefs.getString(vocabRecordingModeKey);
    return RecordingMode.values.firstWhere(
      (mode) => mode.name == raw,
      orElse: () => RecordingMode.intermittent,
    );
  }

  set vocabRecordingMode(RecordingMode value) =>
      _prefs.setString(vocabRecordingModeKey, value.name);

  /// 起動時にスタートアップ（案内）画面を出すか。未設定＝初回は true。
  bool get showStartupScreen => _prefs.getBool(showStartupScreenKey) ?? true;

  set showStartupScreen(bool value) =>
      _prefs.setBool(showStartupScreenKey, value);

  /// レイヤーⅠ単語テスト／単語帳に標準JLPT語彙（各レベル20語）を含めるか。
  /// 未設定＝true（初めての人でもすぐ試験できるようにする）。
  bool get includeDefaultVocabulary =>
      _prefs.getBool(includeDefaultVocabularyKey) ?? true;

  set includeDefaultVocabulary(bool value) =>
      _prefs.setBool(includeDefaultVocabularyKey, value);

  /// レイヤーⅠ単語テストの回答入力方式。既定は音声入力。
  /// Androidでは[AppSettings.vocabAnswerMode]側でキーボード固定に上書きする。
  VocabAnswerMode get vocabAnswerMode {
    final raw = _prefs.getString(vocabAnswerModeKey);
    return VocabAnswerMode.values.firstWhere(
      (mode) => mode.name == raw,
      orElse: () => VocabAnswerMode.voice,
    );
  }

  set vocabAnswerMode(VocabAnswerMode value) =>
      _prefs.setString(vocabAnswerModeKey, value.name);

  /// レイヤーⅠ単語テスト（単体版・総評画面の「分からなかった単語だけ
  /// テスト」の両方）の回答言語（🇻🇳/🇺🇸/🇯🇵トグル）の明示的な選択。
  /// 未設定（null）＝ユーザーがまだ一度も切り替えていない。その場合は
  /// 呼び出し側が表示言語（[language]）から既定値を導く。
  String? get vocabAnswerLanguageCode =>
      _prefs.getString(vocabAnswerLanguageCodeKey);

  set vocabAnswerLanguageCode(String? value) {
    if (value == null) {
      _prefs.remove(vocabAnswerLanguageCodeKey);
    } else {
      _prefs.setString(vocabAnswerLanguageCodeKey, value);
    }
  }

  /// 長文読解の長押し＋ドラッグ単語選択のヒットテスト単位。既定は文字単位。
  LongArticleWordSelectionMode get longArticleWordSelectionMode =>
      longArticleWordSelectionModeFromStorageKey(
        _prefs.getString(longArticleWordSelectionModeKey),
      );

  set longArticleWordSelectionMode(LongArticleWordSelectionMode value) =>
      _prefs.setString(longArticleWordSelectionModeKey, value.storageKey);

  /// ダブルタップの機能ヒント（Step 7の[ButtonActionHint]）を、時間経過
  /// ではなく次のアクションが入るまで表示し続けるか。既定はfalse（OFF＝
  /// [buttonHintDisplaySeconds]が過ぎたら自動的に消える）。
  bool get buttonHintPersistUntilNextAction =>
      _prefs.getBool(buttonHintPersistUntilNextActionKey) ?? false;

  set buttonHintPersistUntilNextAction(bool value) =>
      _prefs.setBool(buttonHintPersistUntilNextActionKey, value);

  /// [buttonHintPersistUntilNextAction]がOFFのときの自動消去までの秒数。
  /// 未設定・[buttonHintDisplaySecondsOptions]に無い値は既定の3秒に戻す。
  int get buttonHintDisplaySeconds {
    final raw = _prefs.getInt(buttonHintDisplaySecondsKey);
    if (raw == null || !buttonHintDisplaySecondsOptions.contains(raw)) {
      return defaultButtonHintDisplaySeconds;
    }
    return raw;
  }

  set buttonHintDisplaySeconds(int value) =>
      _prefs.setInt(buttonHintDisplaySecondsKey, value);
}
