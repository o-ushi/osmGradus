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
    appSettings.showStartupScreen = true;
    appSettings.showUsageScreen = true;
  });

  testWidgets('ボタンヒントのセクションが既定値（OFF・3秒）で表示される（Step 8）', (tester) async {
    await _openSettings(tester);

    expect(find.text(_t('ボタンヒント_設定セクション')), findsOneWidget);
    expect(find.text(_t('ボタンヒント_次のアクションまで表示')), findsOneWidget);
    final switchWidget = tester.widget<Switch>(
      find.descendant(
        of: find.widgetWithText(SettingsSwitchRow, _t('ボタンヒント_次のアクションまで表示')),
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

  test('showUsageScreenは未設定なら既定true、設定するとリロード後も保持される（Step 1）', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await AppPreferences.load();
    expect(prefs.showUsageScreen, isTrue);

    prefs.showUsageScreen = false;
    final reloaded = await AppPreferences.load();
    expect(reloaded.showUsageScreen, isFalse);
  });

  testWidgets('設定画面に使い方画面スイッチが出て、トグルで値が変わる（Step 1）', (tester) async {
    await _openSettings(tester);

    expect(find.text(_t('使い方画面')), findsOneWidget);
    final switchWidget = tester.widget<Switch>(
      find.descendant(
        of: find.widgetWithText(SettingsSwitchRow, _t('使い方画面')),
        matching: find.byType(Switch),
      ),
    );
    expect(switchWidget.value, isTrue);

    await tester.tap(find.text(_t('使い方画面')));
    await tester.pumpAndSettle();

    expect(appSettings.showUsageScreen, isFalse);
  });

  test('スタートアップをOFFにすると使い方も自動でOFFになる（連動Step1）', () {
    appSettings.showStartupScreen = true;
    appSettings.showUsageScreen = true;

    appSettings.showStartupScreen = false;

    expect(appSettings.showUsageScreen, isFalse);
  });

  test('スタートアップを再びONにしても使い方は自動で戻らない（連動Step1）', () {
    appSettings.showStartupScreen = true;
    appSettings.showUsageScreen = true;
    appSettings.showStartupScreen = false;
    expect(appSettings.showUsageScreen, isFalse);

    appSettings.showStartupScreen = true;

    expect(appSettings.showUsageScreen, isFalse);
  });

  test('スタートアップONのまま使い方だけOFFにしてもスタートアップはONのまま（連動Step1）', () {
    appSettings.showStartupScreen = true;
    appSettings.showUsageScreen = true;

    appSettings.showUsageScreen = false;

    expect(appSettings.showStartupScreen, isTrue);
  });

  testWidgets('スタートアップOFFのとき使い方スイッチはenabled:falseでタップしても変わらない（連動Step1）', (
    tester,
  ) async {
    appSettings.showStartupScreen = false;
    await _openSettings(tester);

    final row = tester.widget<SettingsSwitchRow>(
      find.widgetWithText(SettingsSwitchRow, _t('使い方画面')),
    );
    expect(row.enabled, isFalse);

    await tester.tap(find.text(_t('使い方画面')));
    await tester.pumpAndSettle();

    expect(appSettings.showUsageScreen, isFalse);
  });
}
