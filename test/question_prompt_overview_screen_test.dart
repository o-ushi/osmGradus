import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/audio/podcast_audio_handler.dart';
import 'package:osm_gradus/localization/app_strings.dart';
import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/models/question_prompt.dart';
import 'package:osm_gradus/models/question_prompt_source.dart';
import 'package:osm_gradus/models/topic_category.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/services/jsst_calibration_preferences.dart';
import 'package:osm_gradus/services/podcast_library_service.dart';
import 'package:osm_gradus/services/question_prompt_service.dart';
import 'package:osm_gradus/services/topic_speech_reader.dart';
import 'package:osm_gradus/services/tts_settings_service.dart';
import 'package:osm_gradus/views/launch_screen.dart';
import 'package:osm_gradus/widgets/app_header.dart';
import 'package:osm_gradus/widgets/question_prompt_overview_row.dart';

const _lang = 'vi';
String _t(String key) => key.tr(_lang);

/// 起動画面の「問題文一覧」（横断一覧、[QuestionPromptOverviewScreen]）から
/// レイヤー詳細を開く経路の回帰テスト。MainShell内の各レイヤー一覧から開く
/// 経路とは別に、この一覧はMainShellを経由せず起動画面から直接pushされる
/// ため、常設[AppHeader]の長押しが独立して正しく配線されているかを別途確認する。
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      AppPreferences.showStartupScreenKey: false,
    });
    appPreferences.showStartupScreen = false;
  });

  testWidgets('起動画面の「問題文一覧」から開いたレイヤー詳細で、常設ヘッダーを長押しすると'
      '一覧ではなくスタート画面へジャンプする', (tester) async {
    await QuestionPromptService().importPrompts([
      QuestionPrompt.create(
        field: TopicCategory.daily,
        body: '横断一覧テスト問題文',
        source: QuestionPromptSource.manual,
      ),
    ]);

    await tester.pumpWidget(const OsmGradusApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(_t('問題文一覧')));
    await tester.pumpAndSettle();

    // 総評マーク（⭕️）は未実施のため出ないが、Ⅰ〜Ⅴのレイヤーアイコンは
    // 常にタップできる（[QuestionPromptOverviewRow.onLayerTap]）。
    final firstRow = find.byType(QuestionPromptOverviewRow).first;
    final layer1Icon = find
        .descendant(of: firstRow, matching: find.byType(InkWell))
        .first;
    await tester.tap(layer1Icon);
    await tester.pumpAndSettle();

    // レイヤーⅠ詳細画面が開いていること（常設ヘッダーが存在する）。
    expect(find.byType(AppHeader), findsOneWidget);

    await tester.longPress(
      find.descendant(of: find.byType(AppHeader), matching: find.text('Ⅰ')),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));

    expect(find.byType(LaunchScreen), findsOneWidget);
    expect(find.byType(QuestionPromptOverviewRow), findsNothing);
  });
}
