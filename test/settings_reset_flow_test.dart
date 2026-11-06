import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/audio/podcast_audio_handler.dart';
import 'package:osm_gradus/localization/app_strings.dart';
import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/models/question_prompt_source.dart';
import 'package:osm_gradus/models/topic_category.dart';
import 'package:osm_gradus/models/vocabulary_level.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/services/jsst_calibration_preferences.dart';
import 'package:osm_gradus/services/podcast_library_service.dart';
import 'package:osm_gradus/services/question_prompt_service.dart';
import 'package:osm_gradus/services/topic_speech_reader.dart';
import 'package:osm_gradus/services/tts_settings_service.dart';
import 'package:osm_gradus/services/vocabulary_service.dart';
import 'package:osm_gradus/views/settings/tts_settings_screen.dart';

const _lang = 'vi';
String _t(String key) => key.tr(_lang);

/// ユーザー報告の回帰確認：設定「すべてのデータを初期化」→トップ画面→
/// 「問題文一覧」（[QuestionPromptOverviewScreen]）を開く一連の操作が、
/// 例外・無限ローディングなく完走することを確認する。
///
/// 現時点ではこのウィジェットテスト環境（モックのSharedPreferences・
/// 未実装のプラットフォームチャンネル）ではフリーズを再現できていない。
/// 実機（特に音声認識・TTS・Podcast再生など実プラットフォームチャンネルが
/// 絡む状態）固有の問題である可能性が残るため、実機での切り分け情報が
/// 得られ次第、このテストに再現条件を追加すること。

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
  });

  testWidgets('設定で全て初期化→トップに戻る→問題文一覧を開いてもフリーズしない', (tester) async {
    // 事前に「使い込んだ」状態を作る：手入力問題文・単語帳エントリなど。
    await QuestionPromptService().recordImport(
      category: TopicCategory.daily,
      bodies: ['初期化前に追加した問題文'],
      source: QuestionPromptSource.manual,
    );
    await VocabularyService().addEntry(
      '促進',
      'thúc đẩy',
      reading: 'そくしん',
      level: VocabularyLevel.n2,
    );
    await QuestionPromptService().loadAll();

    // 設定画面が長いので、スクロールなしで全項目が収まる大きな
    // テストサーフェスにしておく。
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const OsmGradusApp());
    await tester.pumpAndSettle();

    // トップ画面「•••」→「設定」
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settings-group-データ')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('すべてのデータを初期化')));
    await tester.pumpAndSettle();

    expect(find.text(_t('本当に初期化しますか？')), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, _t('初期化')));
    await tester.pumpAndSettle();

    // 設定画面から戻ってトップ画面へ（設定画面はスワイプで閉じる方式で、
    // 通常の戻るボタンが無いため直接pop）。
    Navigator.of(tester.element(find.byType(TtsSettingsScreen))).pop();
    await tester.pumpAndSettle();

    // トップ画面「問題文一覧」アイコンをタップ。
    await tester.tap(find.byIcon(Icons.list_alt_rounded));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(tester.takeException(), isNull);
    expect(find.text(_t('問題文一覧')), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 20)));
}
