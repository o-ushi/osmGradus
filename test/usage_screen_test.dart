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
import 'package:osm_gradus/views/startup_screen.dart';
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

  Future<void> swipeFromLeftEdge(WidgetTester tester) async {
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
  }

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

  test('コピー案内の文言に赤丸表現が残っておらず、TAP!の矢印に言及している（連動Step3）', () {
    for (final code in ['ja', 'en', 'vi']) {
      final body = '使い方_コピー本文'.tr(code);
      final imageDescription = '使い方_コピー画像_説明'.tr(code);
      for (final text in [body, imageDescription]) {
        expect(text, isNot(contains('赤丸')));
        expect(text, isNot(contains('red circle')));
        expect(text, isNot(contains('khoanh đỏ')));
      }
      expect(body, contains('TAP!'));
      expect(imageDescription, contains('TAP!'));
    }
  });

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

    await swipeFromLeftEdge(tester);

    expect(tester.takeException(), isNull);
    expect(find.text(t('使い方_タイトル')), findsNothing);
    expect(find.text(t('はじめる')), findsOneWidget);
  });

  testWidgets('使い方画面を左端右スワイプすると、フラグを保存せずスタートアップへ戻る（連動Step2）', (tester) async {
    appSettings.showStartupScreen = true;
    appSettings.showUsageScreen = true;
    tester.view.physicalSize = const Size(390, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const OsmGradusApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text(t('はじめる')));
    await tester.pumpAndSettle();
    expect(find.text(t('使い方_タイトル')), findsOneWidget);

    await swipeFromLeftEdge(tester);

    expect(tester.takeException(), isNull);
    expect(find.text(t('はじめる')), findsOneWidget);
    expect(find.text(t('ホーム画面へ')), findsNothing);
    // 「ホーム画面へ」を押していないのでフラグは変わらない。
    expect(appSettings.showStartupScreen, isTrue);
    expect(appSettings.showUsageScreen, isTrue);

    // スタートアップから再度「はじめる」→ usageがONならまた使い方へ（往復可）。
    await tester.tap(find.text(t('はじめる')));
    await tester.pumpAndSettle();
    expect(find.text(t('使い方_タイトル')), findsOneWidget);
  });

  testWidgets('スタートアップ・使い方の確定ボタンは、スクロールせずに画面下へ固定される', (
    WidgetTester tester,
  ) async {
    // iPhone SE 相当の低い画面でも、長い本文の下に隠れない。
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final (screen, label) in [
      (StartupScreen(onContinue: (_) {}), 'はじめる'),
      (UsageScreen(onContinue: (_) {}), 'ホーム画面へ'),
    ]) {
      await tester.pumpWidget(MaterialApp(home: screen));
      await tester.pumpAndSettle();
      for (final text in [t(label), t('次回から表示しない')]) {
        final rect = tester.getRect(find.text(text));
        expect(rect.bottom, lessThanOrEqualTo(667), reason: text);
        // スクロール領域の外（固定の下部バー）にある。
        expect(
          find.ancestor(
            of: find.text(text),
            matching: find.byType(SingleChildScrollView),
          ),
          findsNothing,
          reason: text,
        );
      }
    }
  });
}
