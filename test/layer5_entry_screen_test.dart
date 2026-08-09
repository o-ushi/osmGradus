import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/localization/app_strings.dart';
import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/services/long_article_service.dart';
import 'package:osm_gradus/services/topic_speech_reader.dart';
import 'package:osm_gradus/services/tts_settings_service.dart';
import 'package:osm_gradus/views/layers/layer5_entry_screen.dart';
import 'package:osm_gradus/views/layers/layer5_long_reading_screen.dart';
import 'package:osm_gradus/views/layers/layer5_screen.dart';
import 'package:osm_gradus/views/layers/long_article_list_screen.dart';

const _lang = 'vi';
String _t(String key) => key.tr(_lang);

Future<Layer5EntryScreenState> _pumpEntry(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: Layer5EntryScreen())),
  );
  await tester.pump();
  return tester.state<Layer5EntryScreenState>(find.byType(Layer5EntryScreen));
}

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

  testWidgets('長文一覧が空のときは「長文」が選べず、案内文が表示される', (WidgetTester tester) async {
    await _pumpEntry(tester);

    expect(find.text(_t('レイヤーⅤ_短文')), findsOneWidget);
    expect(find.text(_t('レイヤーⅤ_長文')), findsOneWidget);
    expect(find.text(_t('レイヤーⅤ_長文_一覧なし')), findsOneWidget);

    await tester.tap(find.text(_t('レイヤーⅤ_長文')));
    await tester.pump();

    // タップしても何も起きない（2択画面のまま）。
    expect(find.byType(Layer5LongReadingScreen), findsNothing);
    expect(find.byType(Layer5Screen), findsNothing);
  });

  testWidgets('長文一覧があるときは「長文」をタップすると一覧から選べて、選ぶと音読画面が開く', (
    WidgetTester tester,
  ) async {
    await LongArticleService().addArticle(
      title: '旅行',
      body: '友達と一緒に旅行に行きました。とても楽しかったです。',
    );

    await _pumpEntry(tester);
    // 一覧の非同期読み込みが終わるまで待つ。
    await tester.pump();

    await tester.tap(find.text(_t('レイヤーⅤ_長文')));
    await tester.pumpAndSettle();

    // ランダムに開かれず、長文一覧から選ぶ画面が開く。
    expect(find.byType(LongArticleListScreen), findsOneWidget);
    expect(find.byType(Layer5LongReadingScreen), findsNothing);

    await tester.tap(find.text('旅行'));
    await tester.pumpAndSettle();

    expect(find.byType(Layer5LongReadingScreen), findsOneWidget);
    expect(find.textContaining('友達と一緒に旅行'), findsOneWidget);
  });

  testWidgets('「短文」をタップすると既存のLayer5Screen（10問セッション）が開く', (
    WidgetTester tester,
  ) async {
    final state = await _pumpEntry(tester);

    await tester.tap(find.text(_t('レイヤーⅤ_短文')));
    await tester.pump();

    expect(find.byType(Layer5Screen), findsOneWidget);
    expect(state.mode, Layer5Mode.short);
  });

  testWidgets('モードを選んだあとにresetModeを呼ぶと2択画面へ戻る', (WidgetTester tester) async {
    final state = await _pumpEntry(tester);

    await tester.tap(find.text(_t('レイヤーⅤ_短文')));
    await tester.pump();
    expect(find.byType(Layer5Screen), findsOneWidget);

    state.resetMode();
    await tester.pump();

    expect(find.byType(Layer5Screen), findsNothing);
    expect(find.text(_t('レイヤーⅤ_短文')), findsOneWidget);
    expect(find.text(_t('レイヤーⅤ_長文')), findsOneWidget);
  });
}
