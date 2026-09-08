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

void main() {
  const lang = 'vi';
  String t(String key) => key.tr(lang);

  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

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
    // 初回インストール相当：スタートアップ・使い方とも表示する。
    appSettings.showStartupScreen = true;
    appSettings.showUsageScreen = true;
  });

  testWidgets('初回起動ではスタートアップ画面が出る', (WidgetTester tester) async {
    expect(appSettings.showStartupScreen, isTrue);

    await tester.pumpWidget(const OsmGradusApp());
    await tester.pumpAndSettle();

    expect(find.text('osmGradus'), findsOneWidget);
    expect(find.text(t('スタートアップ_説明')), findsOneWidget);
    expect(find.text(t('次回から表示しない')), findsOneWidget);
    expect(find.text(t('はじめる')), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
  });

  testWidgets('文字サイズを大きくしてもアプリ名は拡大されず1行に収まる', (WidgetTester tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const OsmGradusApp());
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(find.text('osmGradus'));
    expect(title.maxLines, 1);
    expect(title.textScaler, TextScaler.noScaling);
    expect(title.softWrap, isFalse);

    // システム文字サイズ2倍でも、タイトル高さは等倍の1行分に近い
    // （fontSize 36 + 行メトリクスでおおよそ50前後）。
    final height = tester.getSize(find.text('osmGradus')).height;
    expect(height, lessThan(60));
  });

  testWidgets('端末の文字サイズが等倍未満でも、アプリ内では等倍まで引き上げる（Galaxyの小さめ設定対策）', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 0.7;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const OsmGradusApp());
    await tester.pumpAndSettle();

    final scaler = MediaQuery.textScalerOf(
      tester.element(find.byType(Checkbox)),
    );
    expect(scaler.scale(20), 20);
  });

  testWidgets('端末の文字サイズを大きくした場合は、その倍率をそのまま尊重する', (WidgetTester tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const OsmGradusApp());
    await tester.pumpAndSettle();

    final scaler = MediaQuery.textScalerOf(
      tester.element(find.byType(Checkbox)),
    );
    expect(scaler.scale(20), 30);
  });

  testWidgets('「次回から表示しない」にチェックして始めると、次回は起動画面へ直接進む', (
    WidgetTester tester,
  ) async {
    useTallViewport(tester);
    await tester.pumpWidget(const OsmGradusApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text(t('はじめる')));
    await tester.pumpAndSettle();

    expect(appSettings.showStartupScreen, isFalse);
    // 使い方は既定trueのまま → このセッションは使い方画面を経由する（仕様B）。
    expect(find.text(t('使い方_タイトル')), findsOneWidget);
    await tester.tap(find.text(t('ホーム画面へ')));
    await tester.pumpAndSettle();
    expect(find.text(t('コンセプトサブタイトル')), findsOneWidget);

    // 同じプロセス内で再マウントしても、設定オフならスタートアップも使い方も出ない（仕様A）。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const OsmGradusApp());
    await tester.pumpAndSettle();

    expect(find.text(t('はじめる')), findsNothing);
    expect(find.text(t('使い方_タイトル')), findsNothing);
    expect(find.text(t('コンセプトサブタイトル')), findsOneWidget);
  });

  testWidgets('チェックなしで始めると、次回起動でもスタートアップが再表示される', (WidgetTester tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(const OsmGradusApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text(t('はじめる')));
    await tester.pumpAndSettle();

    expect(appSettings.showStartupScreen, isTrue);
    // 使い方は既定trueのまま → このセッションは使い方画面を経由する（仕様B）。
    expect(find.text(t('使い方_タイトル')), findsOneWidget);
    await tester.tap(find.text(t('ホーム画面へ')));
    await tester.pumpAndSettle();
    expect(find.text(t('コンセプトサブタイトル')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const OsmGradusApp());
    await tester.pumpAndSettle();

    expect(find.text(t('はじめる')), findsOneWidget);
  });

  testWidgets('国旗ボタンをタップすると言語選択シートが開き、選ぶとその場で言語が切り替わる', (
    WidgetTester tester,
  ) async {
    appSettings.language = 'vi';
    await tester.pumpWidget(const OsmGradusApp());
    await tester.pumpAndSettle();

    expect(find.text('🇻🇳'), findsOneWidget);
    expect(find.text('スタートアップ_説明'.tr('vi')), findsOneWidget);

    await tester.tap(find.text('🇻🇳'));
    await tester.pumpAndSettle();

    expect(find.text('English'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(appSettings.language, 'en');
    expect(find.text('🇺🇸'), findsOneWidget);
    expect(find.text('スタートアップ_説明'.tr('en')), findsOneWidget);

    appSettings.language = 'vi';
  });

  testWidgets('起動ON・使い方ONのとき、レイヤー一覧画面から左端の右スワイプで使い方画面に戻る（仕様D）', (
    WidgetTester tester,
  ) async {
    useTallViewport(tester);
    await tester.pumpWidget(const OsmGradusApp());
    await tester.pumpAndSettle();
    // 「次回から表示しない」を付けずに始める → showStartupScreenはtrueのまま。
    await tester.tap(find.text(t('はじめる')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t('ホーム画面へ')));
    await tester.pumpAndSettle();

    expect(appSettings.showStartupScreen, isTrue);
    expect(appSettings.showUsageScreen, isTrue);
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
    expect(find.text(t('使い方_タイトル')), findsOneWidget);
    expect(find.text(t('はじめる')), findsNothing);
    expect(find.text(t('コンセプトサブタイトル')), findsNothing);
  });

  testWidgets('起動ON・使い方OFFのとき、レイヤー一覧画面から左端の右スワイプでスタートアップ画面に戻る（仕様D）', (
    WidgetTester tester,
  ) async {
    useTallViewport(tester);
    appSettings.showUsageScreen = false;
    await tester.pumpWidget(const OsmGradusApp());
    await tester.pumpAndSettle();
    // 「次回から表示しない」を付けずに始める → showStartupScreenはtrueのまま。
    // 使い方はOFFなので「はじめる」の直後にホームへ着地する。
    await tester.tap(find.text(t('はじめる')));
    await tester.pumpAndSettle();

    expect(appSettings.showStartupScreen, isTrue);
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
    expect(find.text(t('はじめる')), findsOneWidget);
    expect(find.text(t('コンセプトサブタイトル')), findsNothing);
  });

  testWidgets('スタートアップ画面表示OFFのとき、レイヤー一覧画面から左端の右スワイプをしても何も起きない', (
    WidgetTester tester,
  ) async {
    useTallViewport(tester);
    await tester.pumpWidget(const OsmGradusApp());
    await tester.pumpAndSettle();
    // 「次回から表示しない」を付けて始める → showStartupScreenはfalseになる。
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text(t('はじめる')));
    await tester.pumpAndSettle();
    // 使い方は既定trueのまま → いったん使い方画面を経由してからホームへ。
    await tester.tap(find.text(t('ホーム画面へ')));
    await tester.pumpAndSettle();

    expect(appSettings.showStartupScreen, isFalse);
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
    expect(find.text(t('はじめる')), findsNothing);
    expect(find.text(t('コンセプトサブタイトル')), findsOneWidget);
  });

  testWidgets('初回（両方true）: 起動→スタートアップ→はじめる→使い方→ホーム画面へ→ホーム（Step 4 ケース1）', (
    WidgetTester tester,
  ) async {
    useTallViewport(tester);
    await tester.pumpWidget(const OsmGradusApp());
    await tester.pumpAndSettle();
    expect(find.text(t('はじめる')), findsOneWidget);

    await tester.tap(find.text(t('はじめる')));
    await tester.pumpAndSettle();
    expect(find.text(t('使い方_タイトル')), findsOneWidget);

    await tester.tap(find.text(t('ホーム画面へ')));
    await tester.pumpAndSettle();
    expect(find.text(t('コンセプトサブタイトル')), findsOneWidget);
  });

  testWidgets(
    'スタートアップはチェックしない、使い方でチェックON→ホーム→再マウント→スタートアップ再表示、はじめる→ホーム（使い方スキップ）（Step 4 ケース3）',
    (WidgetTester tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(const OsmGradusApp());
      await tester.pumpAndSettle();

      // スタートアップの「次回から表示しない」はチェックしない。
      await tester.tap(find.text(t('はじめる')));
      await tester.pumpAndSettle();
      expect(find.text(t('使い方_タイトル')), findsOneWidget);

      // 使い方側は「次回から表示しない」をチェックしてからホームへ。
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text(t('ホーム画面へ')));
      await tester.pumpAndSettle();

      expect(appSettings.showStartupScreen, isTrue);
      expect(appSettings.showUsageScreen, isFalse);
      expect(find.text(t('コンセプトサブタイトル')), findsOneWidget);

      // 再マウント：スタートアップは再表示される。
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(const OsmGradusApp());
      await tester.pumpAndSettle();
      expect(find.text(t('はじめる')), findsOneWidget);

      // はじめる→使い方はOFFのままなのでスキップして直接ホームへ。
      await tester.tap(find.text(t('はじめる')));
      await tester.pumpAndSettle();
      expect(find.text(t('使い方_タイトル')), findsNothing);
      expect(find.text(t('コンセプトサブタイトル')), findsOneWidget);
    },
  );
}
