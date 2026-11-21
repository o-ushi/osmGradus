import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/audio/podcast_audio_handler.dart';
import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/services/jsst_calibration_preferences.dart';
import 'package:osm_gradus/services/podcast_library_service.dart';
import 'package:osm_gradus/services/topic_speech_reader.dart';
import 'package:osm_gradus/services/tts_settings_service.dart';
import 'package:osm_gradus/views/layers/layer2_question_prompt_detail_screen.dart';
import 'package:osm_gradus/views/topics/question_prompt_filter_sheet.dart';
import 'package:osm_gradus/views/topics/question_prompt_list_screen.dart';
import 'package:osm_gradus/widgets/podcast_toolbar.dart';
import 'package:osm_gradus/widgets/question_prompt_list_row.dart';

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

  testWidgets('iPad横：レイヤーの問題文一覧は左、選んだ問題は右に出る', (tester) async {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    appSettings.language = 'ja';

    await tester.pumpWidget(const OsmGradusApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ⅱ').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('問題文一覧から選ぶ'));
    await tester.pumpAndSettle();

    final listTitle = find.text('問題文一覧');
    expect(listTitle, findsWidgets);
    expect(tester.getCenter(listTitle.first).dx, lessThan(683));
    expect(find.byType(QuestionPromptListScreen), findsOneWidget);

    final firstRow = find.byType(QuestionPromptListRow).first;
    expect(tester.getCenter(firstRow).dx, lessThan(683));
    await tester.tap(firstRow);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final detail = find.byType(Layer2QuestionPromptDetailScreen);
    expect(detail, findsOneWidget);
    expect(tester.getTopLeft(detail).dx, greaterThan(683));
    // 一覧は左に残る。
    expect(tester.getCenter(find.text('問題文一覧').first).dx, lessThan(683));

    // 絞り込みシートも左に出る。
    final filterIcon = find.byIcon(Icons.filter_list);
    expect(tester.getCenter(filterIcon.first).dx, lessThan(683));
    await tester.tap(filterIcon.first);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    final sheet = find.byType(QuestionPromptFilterSheet);
    expect(sheet, findsOneWidget);
    expect(tester.getTopRight(sheet).dx, lessThanOrEqualTo(683));
  });

  testWidgets('iPad横：Podcast番組一覧は左に出る', (tester) async {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    appSettings.language = 'ja';

    await tester.pumpWidget(const OsmGradusApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ⅰ').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ポッドキャスト'));
    await tester.pumpAndSettle();

    final toolbar = find.byType(PodcastToolbar);
    expect(toolbar, findsOneWidget);
    expect(tester.getTopRight(toolbar).dx, lessThanOrEqualTo(683));
    expect(find.byIcon(Icons.headphones_rounded), findsOneWidget);
  });

  testWidgets('iPad横：右ペイン上端のステータスバー帯に高さがあり、濃い色で塗られる', (tester) async {
    tester.view.physicalSize = const Size(1376, 1032);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 32);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const OsmGradusApp());
    await tester.pumpAndSettle();

    final band = find.byWidgetPredicate(
      (w) => w is Positioned && w.top == 0 && w.height == 32,
    );
    expect(band, findsOneWidget);
    final fill = find.descendant(of: band, matching: find.byType(ColoredBox));
    final size = tester.getSize(fill);
    expect(size.height, 32);
    expect(tester.getTopLeft(fill).dx, greaterThan(680));
  });
}
