import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/audio/podcast_audio_handler.dart';
import 'package:osm_gradus/localization/app_strings.dart';
import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/models/question_prompt_source.dart';
import 'package:osm_gradus/models/topic_category.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/services/jsst_calibration_preferences.dart';
import 'package:osm_gradus/services/podcast_library_service.dart';
import 'package:osm_gradus/services/question_prompt_service.dart';
import 'package:osm_gradus/services/question_prompt_tab_registry.dart';
import 'package:osm_gradus/services/topic_speech_reader.dart';
import 'package:osm_gradus/services/tts_settings_service.dart';
import 'package:osm_gradus/views/topics/question_prompt_edit_screen.dart';
import 'package:osm_gradus/widgets/question_prompt_list_row.dart';

const _lang = 'vi';
String _t(String key) => key.tr(_lang);

Future<void> _openQuestionPromptList(WidgetTester tester) async {
  await tester.pumpWidget(const OsmGradusApp());
  await tester.tap(find.text('Tầng I'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(_t('問題文解析')));
  await tester.pumpAndSettle();
}

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

  testWidgets('本文を長押しすると編集画面が開く（question-prompt-tabs.md Step 5）', (
    tester,
  ) async {
    await _openQuestionPromptList(tester);

    await tester.longPress(find.byType(QuestionPromptListRow).first);
    await tester.pumpAndSettle();

    expect(find.byType(QuestionPromptEditScreen), findsOneWidget);
    expect(find.text(_t('問題文を編集')), findsOneWidget);
  });

  testWidgets('generalの問題文はタブ変更が保存される', (tester) async {
    final all = await QuestionPromptService().loadAll();
    final target = all.firstWhere((p) => p.category == TopicCategory.general);

    await _openQuestionPromptList(tester);
    await tester.longPress(
      find.widgetWithText(QuestionPromptListRow, target.body),
    );
    await tester.pumpAndSettle();
    expect(find.byType(QuestionPromptEditScreen), findsOneWidget);

    // まだ選ばれていない「会社」タブを追加選択して保存する。
    await tester.tap(find.widgetWithText(FilterChip, _t('会社')));
    await tester.pump();
    await tester.tap(find.text(_t('保存')));
    await tester.pumpAndSettle();

    final updatedAll = await QuestionPromptService().loadAll();
    final updated = updatedAll.singleWhere((p) => p.id == target.id);
    expect(updated.tags, containsAll([...target.tags, '会社']));
  });

  testWidgets('組み込み問題を編集してreloadしてもtagsが保持される（バンク値に戻らない）', (tester) async {
    final all = await QuestionPromptService().loadAll();
    final target = all.firstWhere(
      (p) =>
          p.source == QuestionPromptSource.builtIn &&
          p.category == TopicCategory.general,
    );

    await _openQuestionPromptList(tester);
    await tester.longPress(
      find.widgetWithText(QuestionPromptListRow, target.body),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, _t('会社')));
    await tester.pump();
    await tester.tap(find.text(_t('保存')));
    await tester.pumpAndSettle();

    // 相当する新しいセッションを模して、もう一度loadAllを呼んでも
    // バンク側のタグに巻き戻らないこと（contentEditedガード、Step 5）。
    final reloaded = await QuestionPromptService().loadAll();
    final reloadedTarget = reloaded.singleWhere((p) => p.id == target.id);
    expect(reloadedTarget.tags, containsAll([...target.tags, '会社']));
  });

  testWidgets('シチュエーション問題は状況・条件の両方を編集できる', (tester) async {
    final all = await QuestionPromptService().loadAll();
    final target = all.firstWhere(
      (p) => p.category == TopicCategory.situational,
    );

    await _openQuestionPromptList(tester);
    await tester.scrollUntilVisible(
      find.text(target.body),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.longPress(
      find.widgetWithText(QuestionPromptListRow, target.body),
    );
    await tester.pumpAndSettle();
    expect(find.byType(QuestionPromptEditScreen), findsOneWidget);

    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(2));
    await tester.enterText(textFields.at(0), '編集後の状況文');
    await tester.enterText(textFields.at(1), '編集後の条件文');
    await tester.tap(find.text(_t('保存')));
    await tester.pumpAndSettle();

    final updatedAll = await QuestionPromptService().loadAll();
    final updated = updatedAll.singleWhere((p) => p.id == target.id);
    expect(updated.body, '編集後の状況文');
    expect(updated.situationCondition, '編集後の条件文');
    expect(updated.category, TopicCategory.situational);
    expect(updated.tags, isEmpty);
  });

  testWidgets('「＋新しいタブ」で独自タブを作成すると即座に選択状態になり、保存される', (tester) async {
    final all = await QuestionPromptService().loadAll();
    final target = all.firstWhere((p) => p.category == TopicCategory.general);

    await _openQuestionPromptList(tester);
    await tester.scrollUntilVisible(
      find.text(target.body),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.longPress(
      find.widgetWithText(QuestionPromptListRow, target.body),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ActionChip, _t('新しいタブ')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'スポーツ');
    await tester.tap(find.text(_t('追加')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilterChip, 'スポーツ'), findsOneWidget);

    await tester.tap(find.text(_t('保存')));
    await tester.pumpAndSettle();

    final updatedAll = await QuestionPromptService().loadAll();
    final updated = updatedAll.singleWhere((p) => p.id == target.id);
    expect(updated.tags, contains('スポーツ'));

    final tabKeys = await QuestionPromptTabRegistry().allTabKeys();
    expect(tabKeys, contains('スポーツ'));
  });
}
