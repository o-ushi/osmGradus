import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/audio/podcast_audio_handler.dart';
import 'package:osm_gradus/localization/app_strings.dart';
import 'package:osm_gradus/localization/gradus_l10n.dart';
import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/services/jsst_calibration_preferences.dart';
import 'package:osm_gradus/services/podcast_library_service.dart';
import 'package:osm_gradus/services/topic_speech_reader.dart';
import 'package:osm_gradus/services/tts_settings_service.dart';
import 'package:osm_gradus/views/settings/privacy_data_screen.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      AppPreferences.showStartupScreenKey: false,
    });
    appPreferences = await AppPreferences.load();
    appSettings = AppSettings(appPreferences);
    audioHandler = PodcastAudioHandler(PodcastLibraryService());
    ttsSettings = TtsSettingsService();
    topicSpeechReader = TopicSpeechReader(ttsSettings);
    jsstCalibrationPreferences = JsstCalibrationPreferences();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({
      AppPreferences.showStartupScreenKey: false,
    });
    appPreferences.showStartupScreen = false;
  });

  testWidgets('起動画面に5つのレイヤーが表示され、タップでメインシェルへ遷移する', (WidgetTester tester) async {
    const lang = 'vi';
    await tester.pumpWidget(const OsmGradusApp());

    expect(find.text('コンセプトサブタイトル'.tr(lang)), findsOneWidget);

    final firstTitle = LaunchLayers.items.first.titleKey.tr(lang);
    expect(find.text(firstTitle), findsOneWidget);
    await tester.tap(find.text(firstTitle));
    await tester.pumpAndSettle();

    for (final numeral in const ['Ⅰ', 'Ⅱ', 'Ⅲ', 'Ⅳ', 'Ⅴ']) {
      expect(find.text(numeral), findsWidgets);
    }
  });

  testWidgets('起動画面下の設定ボタンから設定画面を開ける', (WidgetTester tester) async {
    const lang = 'vi';
    await tester.pumpWidget(const OsmGradusApp());

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('設定'.tr(lang)), findsOneWidget);
    expect(find.text('言語'.tr(lang)), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('声質'.tr(lang)),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('声質'.tr(lang)), findsOneWidget);
    expect(find.text('読み上げ速度'.tr(lang)), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('すべてのデータを初期化'.tr(lang)),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('すべてのデータを初期化'.tr(lang)), findsOneWidget);
  });

  testWidgets('狭い画面でも起動画面の「…」メニューが開ける（iPhone SE相当）', (
    WidgetTester tester,
  ) async {
    // メニュー固有幅356 + 余白で、旧実装は clamp 下限>上限で落ちていた。
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const OsmGradusApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.workspace_premium_outlined), findsOneWidget);
    expect(find.byIcon(Icons.upload_outlined), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('iPad Air 11-inch相当の縦横でプライバシー画面が表示できる', (
    WidgetTester tester,
  ) async {
    for (final size in const [Size(834, 1194), Size(1194, 834)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const MaterialApp(home: PrivacyDataScreen()));
      await tester.pumpAndSettle();

      expect(find.text('プライバシーとデータ'.tr('vi')), findsOneWidget);
      expect(find.text('音声認識'.tr('vi')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
