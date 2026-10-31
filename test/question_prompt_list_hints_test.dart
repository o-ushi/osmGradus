import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/localization/app_strings.dart';
import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/widgets/button_action_hint.dart';
import 'package:osm_gradus/widgets/question_prompt_list_row.dart';

const _lang = 'vi';
String _t(String key) => key.tr(_lang);

String _hintMessage(String tapText, {String? longPressText}) =>
    '${'ボタンヒント_タップ'.trFmt(_lang, [tapText])}\n'
    '${'ボタンヒント_長押し'.trFmt(_lang, [longPressText ?? _t('ボタンヒント_長押しなし')])}';

Future<void> _doubleTap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    appPreferences = await AppPreferences.load();
    appSettings = AppSettings(appPreferences);
  });

  testWidgets('行をダブルタップすると選択・編集のヒントが出る', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => ButtonActionHintOverlay(child: child!),
        home: Scaffold(
          body: QuestionPromptListRow(
            done: false,
            body: 'テスト問題文',
            tags: const ['趣味'],
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _doubleTap(tester, find.byType(QuestionPromptListRow));
    await tester.pumpAndSettle();

    expect(
      find.text(
        _hintMessage(
          _t('問題文一覧_ヒント_行_タップ'),
          longPressText: _t('問題文一覧_ヒント_行_長押し'),
        ),
      ),
      findsOneWidget,
    );
  });
}
