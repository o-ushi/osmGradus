import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/audio/podcast_audio_handler.dart';
import 'package:osm_gradus/localization/app_strings.dart';
import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/services/jsst_calibration_preferences.dart';
import 'package:osm_gradus/services/podcast_library_service.dart';
import 'package:osm_gradus/services/topic_speech_reader.dart';
import 'package:osm_gradus/services/tts_settings_service.dart';
import 'package:osm_gradus/views/settings/tts_settings_screen.dart';
import 'package:osm_gradus/widgets/settings_section.dart';

const _lang = 'vi';
String _t(String key) => key.tr(_lang);

Future<void> _openSettings(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: TtsSettingsScreen(
        settings: ttsSettings,
        speechReader: topicSpeechReader,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    appPreferences = await AppPreferences.load();
    appSettings = AppSettings(appPreferences);
    audioHandler = PodcastAudioHandler(PodcastLibraryService());
    ttsSettings = TtsSettingsService();
    topicSpeechReader = TopicSpeechReader(ttsSettings);
    jsstCalibrationPreferences = JsstCalibrationPreferences();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appSettings.buttonHintPersistUntilNextAction = false;
    appSettings.buttonHintDisplaySeconds =
        AppPreferences.defaultButtonHintDisplaySeconds;
  });

  testWidgets('ボタンヒントのセクションが既定値（OFF・3秒）で表示される（Step 8）', (tester) async {
    await _openSettings(tester);

    expect(find.text(_t('ボタンヒント_設定セクション')), findsOneWidget);
    expect(find.text(_t('ボタンヒント_次のアクションまで表示')), findsOneWidget);
    final switchWidget = tester.widget<Switch>(
      find.descendant(
        of: find.widgetWithText(
          SettingsSwitchRow,
          _t('ボタンヒント_次のアクションまで表示'),
        ),
        matching: find.byType(Switch),
      ),
    );
    expect(switchWidget.value, isFalse);
    expect(find.text('ボタンヒント_表示期間_秒'.trFmt(_lang, ['3'])), findsOneWidget);
  });

  testWidgets('スイッチをONにすると保存され、表示期間の行がグレーアウトしてタップできなくなる（Step 8）', (
    tester,
  ) async {
    await _openSettings(tester);

    await tester.tap(find.text(_t('ボタンヒント_次のアクションまで表示')));
    await tester.pumpAndSettle();

    expect(appSettings.buttonHintPersistUntilNextAction, isTrue);
    final valueRow = tester.widget<SettingsValueRow>(
      find.byType(SettingsValueRow).last,
    );
    expect(valueRow.enabled, isFalse);

    // グレーアウト中はタップしてもピッカーが開かない。
    await tester.tap(find.text('ボタンヒント_表示期間_秒'.trFmt(_lang, ['3'])));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoActionSheet), findsNothing);
  });

  testWidgets('表示期間をタップすると選択肢が出て、選ぶと即座に反映される（Step 8）', (tester) async {
    await _openSettings(tester);

    await tester.tap(find.text('ボタンヒント_表示期間_秒'.trFmt(_lang, ['3'])));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    for (final seconds in AppPreferences.buttonHintDisplaySecondsOptions) {
      expect(
        find.text('ボタンヒント_表示期間_秒'.trFmt(_lang, ['$seconds'])),
        findsWidgets,
      );
    }

    await tester.tap(find.text('ボタンヒント_表示期間_秒'.trFmt(_lang, ['8'])).last);
    await tester.pumpAndSettle();

    expect(appSettings.buttonHintDisplaySeconds, 8);
    expect(find.text('ボタンヒント_表示期間_秒'.trFmt(_lang, ['8'])), findsOneWidget);
  });
}
