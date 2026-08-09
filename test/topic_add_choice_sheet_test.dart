import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/localization/app_strings.dart';
import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/models/topic_category.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/views/topics/topic_add_flow.dart';

const _lang = 'vi';
String _t(String key) => key.tr(_lang);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    appPreferences = await AppPreferences.load();
    appSettings = AppSettings(appPreferences);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('お題を追加シートに「AIで追加」「自分で追加」「ファイルをインポート」「エクスポート」の'
      '4つの選択肢が並ぶ（Step 13でファイルインポート表記に明確化）', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showTopicAddChoiceFlow(
                context,
                initialCategory: TopicCategory.daily,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text(_t('AIで追加')), findsOneWidget);
    expect(find.text(_t('自分で追加')), findsOneWidget);
    expect(find.text(_t('ファイルをインポート')), findsOneWidget);
    expect(find.text(_t('エクスポート')), findsOneWidget);
    expect(find.text(_t('お題_追加_説明_ファイルインポート')), findsOneWidget);
  });

  testWidgets('取り込み済みお題が無い状態で「エクスポート」をタップしても例外を出さず、'
      '「お題がありません」のスナックバーを出す', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showTopicAddChoiceFlow(
                context,
                initialCategory: TopicCategory.daily,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(_t('エクスポート')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(_t('エクスポートするお題がありません')), findsOneWidget);
  });
}
