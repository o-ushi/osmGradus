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
import 'package:osm_gradus/views/launch_screen.dart';
import 'package:osm_gradus/views/settings/tts_settings_screen.dart';
import 'package:osm_gradus/views/usage_screen.dart';

void main() {
  const lang = 'vi';
  String t(String key) => key.tr(lang);

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
    appSettings.language = lang;
  });

  Future<void> pumpUsage(
    WidgetTester tester, {
    required ValueChanged<bool> onContinue,
  }) async {
    tester.view.physicalSize = const Size(390, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: UsageScreen(onContinue: onContinue)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('使い方画面が仕様の説明・画像・チェック・ボタンをすべて表示する', (tester) async {
    await pumpUsage(tester, onContinue: (_) {});

    expect(find.text(t('使い方_タイトル')), findsOneWidget);
    expect(find.text(t('使い方_コピー本文')), findsOneWidget);
    expect(find.text(t('使い方_プラス長押し')), findsOneWidget);
    expect(find.text(t('使い方_ダブルタップ')), findsOneWidget);
    expect(find.text(t('次回から表示しない')), findsOneWidget);
    expect(find.text(t('ホーム画面へ')), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);

    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      'assets/images/chrome_ai_copy_button.png',
    );
  });

  testWidgets('チェックして「ホーム画面へ」を押すとonContinue(true)、未チェックならonContinue(false)', (
    tester,
  ) async {
    bool? result;
    await pumpUsage(tester, onContinue: (value) => result = value);

    await tester.tap(find.text(t('ホーム画面へ')));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    result = null;
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text(t('ホーム画面へ')));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('起動画面（初回・OsmGradusApp）には起動_操作ヒントが出ない', (tester) async {
    appSettings.showStartupScreen = true;
    await tester.pumpWidget(const OsmGradusApp());
    await tester.pumpAndSettle();

    expect(find.text(t('起動_操作ヒント')), findsNothing);
  });

  testWidgets('ホーム画面（LaunchScreen）には起動_操作ヒントが残っている', (tester) async {
    await tester.pumpWidget(MaterialApp(home: LaunchScreen()));
    await tester.pumpAndSettle();

    expect(find.text(t('起動_操作ヒント')), findsOneWidget);
  });

  testWidgets('国旗ボタンをタップすると使い方画面の本文の言語が切り替わる（Step 4 ケース9）', (tester) async {
    appSettings.language = 'vi';
    await pumpUsage(tester, onContinue: (_) {});

    expect(find.text('🇻🇳'), findsOneWidget);
    expect(find.text('使い方_コピー本文'.tr('vi')), findsOneWidget);

    await tester.tap(find.text('🇻🇳'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(appSettings.language, 'en');
    expect(find.text('使い方_コピー本文'.tr('en')), findsOneWidget);

    appSettings.language = 'vi';
  });

  testWidgets('設定画面で使い方スイッチをOFFにすると、ホームからのスワイプ先がスタートアップに変わる（Step 4 ケース8）', (
    tester,
  ) async {
    appSettings.showStartupScreen = true;
    appSettings.showUsageScreen = true;

    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 設定画面で使い方スイッチをOFFにする。
    await tester.pumpWidget(
      MaterialApp(
        home: TtsSettingsScreen(
          settings: ttsSettings,
          speechReader: topicSpeechReader,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(t('使い方画面')));
    await tester.pumpAndSettle();
    expect(appSettings.showUsageScreen, isFalse);

    // ホーム画面から左端右スワイプすると、使い方ではなくスタートアップに着地する。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const OsmGradusApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text(t('はじめる')));
    await tester.pumpAndSettle();
    expect(find.text(t('コンセプトサブタイトル')), findsOneWidget);

    final gesture = await tester.startGesture(const Offset(16, 300));
    await gesture.moveBy(
      const Offset(40, 0),
      timeStamp: const Duration(milliseconds: 10),
    );
    await gesture.moveBy(
      const Offset(80, 0),
      timeStamp: const Duration(milliseconds: 20),
    );
    await gesture.moveBy(
      const Offset(120, 0),
      timeStamp: const Duration(milliseconds: 30),
    );
    await gesture.up(timeStamp: const Duration(milliseconds: 30));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(t('使い方_タイトル')), findsNothing);
    expect(find.text(t('はじめる')), findsOneWidget);
  });
}
