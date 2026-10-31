import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/localization/app_strings.dart';
import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/services/question_prompt_tab_registry.dart';
import 'package:osm_gradus/services/topic_speech_reader.dart';
import 'package:osm_gradus/services/tts_settings_service.dart';
import 'package:osm_gradus/views/settings/question_prompt_tab_settings_screen.dart';
import 'package:osm_gradus/views/settings/tts_settings_screen.dart';

const _lang = 'vi';
String _t(String key) => key.tr(_lang);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    appPreferences = await AppPreferences.load();
    appSettings = AppSettings(appPreferences);
    ttsSettings = TtsSettingsService();
    topicSpeechReader = TopicSpeechReader(ttsSettings);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('設定画面からタブ管理画面を開ける', (tester) async {
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

    await tester.scrollUntilVisible(
      find.text(_t('問題文タブの管理')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(_t('問題文タブの管理')));
    await tester.pumpAndSettle();

    expect(find.byType(QuestionPromptTabSettingsScreen), findsOneWidget);
    expect(find.text(_t('組み込みタブ')), findsOneWidget);
    expect(find.text(_t('独自タブ')), findsOneWidget);
  });

  testWidgets('独自タブをリネームできる', (tester) async {
    await QuestionPromptTabRegistry().addCustomTab('スポーツ');

    await tester.pumpWidget(
      const MaterialApp(home: QuestionPromptTabSettingsScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(_t('タブ名を変更')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '音楽');
    await tester.tap(find.text(_t('保存')));
    await tester.pumpAndSettle();

    expect(await QuestionPromptTabRegistry().customTabKeys(), ['音楽']);
    expect(find.text('音楽'), findsOneWidget);
  });
}
