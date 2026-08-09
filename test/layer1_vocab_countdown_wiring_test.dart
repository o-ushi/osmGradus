import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/localization/app_strings.dart';
import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/models/vocab_answer_mode.dart';
import 'package:osm_gradus/models/vocabulary_level.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/services/jsst_calibration_preferences.dart';
import 'package:osm_gradus/services/privacy_consent_service.dart';
import 'package:osm_gradus/services/topic_speech_reader.dart';
import 'package:osm_gradus/services/tts_settings_service.dart';
import 'package:osm_gradus/services/vocabulary_service.dart';
import 'package:osm_gradus/views/layers/layer1_vocab_screen.dart';
import 'package:osm_gradus/widgets/pronunciation_mic_button.dart';
import 'package:osm_gradus/widgets/vocab_countdown_button.dart';

const _lang = 'ja';
String _t(String key) => key.tr(_lang);

Finder get _vocabDiceButton => find.byWidgetPredicate(
  (widget) =>
      widget is Icon && widget.icon == Icons.casino && (widget.size ?? 0) >= 40,
);

Future<void> _pumpLayer1VocabStandalone(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: Layer1VocabScreen())),
  );
  await tester.pump();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      AppPreferences.showStartupScreenKey: false,
    });
    appPreferences = await AppPreferences.load();
    appSettings = AppSettings(appPreferences);
    ttsSettings = TtsSettingsService();
    topicSpeechReader = TopicSpeechReader(ttsSettings);
    jsstCalibrationPreferences = JsstCalibrationPreferences();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      AppPreferences.showStartupScreenKey: false,
    });
    appPreferences.showStartupScreen = false;
    await PrivacyConsentService.grantSpeechProcessingConsent();
    appSettings.vocabAnswerMode = VocabAnswerMode.voice;
    appSettings.language = _lang;
  });

  testWidgets('音声モードで録音中は赤マイクの代わりにVocabCountdownButton（10秒）が'
      '表示され、タップで早期終了して録音が止まりサイコロに戻る', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await VocabularyService().addEntry(
      '単語',
      'từ vựng',
      level: VocabularyLevel.n1,
    );
    await _pumpLayer1VocabStandalone(tester);

    await tester.tap(_vocabDiceButton);
    await tester.pump();
    final state = tester.state<Layer1VocabScreenState>(
      find.byType(Layer1VocabScreen),
    );
    expect(state.debugArmed, isTrue);
    expect(find.byType(VocabCountdownButton), findsNothing);

    // ネイティブ録音を経由せず「録音中」を模擬する（レイヤーⅤの
    // debugForceRecordingStatusと同じ理由）。
    state.debugForceRecording();
    await tester.pump();

    expect(state.debugRecording, isTrue);
    expect(find.byIcon(Icons.mic_rounded), findsNothing);
    final countdown = tester.state<VocabCountdownButtonState>(
      find.byType(VocabCountdownButton),
    );
    expect(countdown.debugRemainingSeconds, 10);
    expect(countdown.debugIsRunning, isTrue);

    await tester.tap(find.byType(VocabCountdownButton));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(state.debugArmed, isFalse);
    expect(state.debugRecording, isFalse);
    expect(_vocabDiceButton, findsOneWidget);
    expect(find.text(_t('うまく聞き取れませんでした。もう一度録音してみましょう。')), findsOneWidget);
  });

  testWidgets('音声モードで録音中に10秒経過すると自動的に録音が止まりサイコロに戻る', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await VocabularyService().addEntry(
      '単語',
      'từ vựng',
      level: VocabularyLevel.n1,
    );
    await _pumpLayer1VocabStandalone(tester);

    await tester.tap(_vocabDiceButton);
    await tester.pump();
    final state = tester.state<Layer1VocabScreenState>(
      find.byType(Layer1VocabScreen),
    );

    state.debugForceRecording();
    await tester.pump();
    expect(find.byType(VocabCountdownButton), findsOneWidget);

    await tester.pump(const Duration(seconds: 10));

    expect(tester.takeException(), isNull);
    expect(state.debugArmed, isFalse);
    expect(state.debugRecording, isFalse);
    expect(_vocabDiceButton, findsOneWidget);
  });

  testWidgets('キーボード回答モードではVocabCountdownButtonを使わない（音声モード専用）', (tester) async {
    appSettings.vocabAnswerMode = VocabAnswerMode.keyboard;
    addTearDown(() => appSettings.vocabAnswerMode = VocabAnswerMode.voice);
    SharedPreferences.setMockInitialValues({});
    await VocabularyService().addEntry(
      '単語',
      'từ vựng',
      level: VocabularyLevel.n1,
    );
    await _pumpLayer1VocabStandalone(tester);

    // 未開始（サイコロ代わりのPronunciationMicButton、armed/recordingとも
    // false）の時点でVocabCountdownButtonは存在しない。
    expect(find.byType(PronunciationMicButton), findsOneWidget);
    expect(find.byType(VocabCountdownButton), findsNothing);

    // サイコロ代わりのボタンをタップして回答欄をアクティブにしても、
    // キーボードモードは録音を伴わないためVocabCountdownButtonは現れない
    // （タイマーの分岐は`!_isKeyboardMode`側にしか存在しない）。
    await tester.tap(_vocabDiceButton);
    await tester.pump();

    expect(find.byType(VocabCountdownButton), findsNothing);
  });
}
