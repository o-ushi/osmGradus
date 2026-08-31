import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/localization/app_strings.dart';
import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/models/topic_category.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/services/question_prompt_service.dart';
import 'package:osm_gradus/views/topics/topic_manual_add_screen.dart';

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

  Future<void> openScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => TopicManualAddScreen.push(
              context,
              initialCategory: TopicCategory.general,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('カテゴリ選択はその他／シチュエーションの2択（日常・ビジネスは出ない、question-prompt-tabs.md Step 4）', (
    tester,
  ) async {
    await openScreen(tester);

    await tester.tap(find.text(_t('問題文カテゴリ_その他')));
    await tester.pumpAndSettle();
    expect(find.text(_t('シチュエーション')), findsOneWidget);
    expect(find.text(_t('日常')), findsNothing);
    expect(find.text(_t('ビジネス')), findsNothing);
  });

  testWidgets('その他のまま追加すると自動タグ付けされたgeneral問題として保存される（Step 4）', (
    tester,
  ) async {
    await openScreen(tester);

    await tester.enterText(find.byType(TextField), '週末はキャンプに行きます');
    await tester.pump();
    await tester.tap(find.text(_t('追加')));
    await tester.pump();

    final all = await QuestionPromptService().loadAll();
    final added = all.singleWhere((p) => p.body == '週末はキャンプに行きます');
    expect(added.category, TopicCategory.general);
    expect(added.tags, isNotEmpty);
  });
}
