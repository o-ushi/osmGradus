import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/localization/app_strings.dart';
import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/models/long_article_comprehension_check.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/views/layers/long_article_comprehension_check_screen.dart';

String _t(String key) => key.tr(appSettings.language);

const _check = LongArticleComprehensionCheck(
  question: '誰と旅行に行きましたか？',
  optionA: '友達',
  optionB: '家族',
  correctOption: 'A',
  explanation: '本文に「友達と一緒に」とある。',
);

Future<void> _pumpScreen(
  WidgetTester tester, {
  required VoidCallback onComplete,
  LongArticleComprehensionCheck check = _check,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: LongArticleComprehensionCheckScreen(
        check: check,
        onComplete: onComplete,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    appPreferences = await AppPreferences.load();
    appSettings = AppSettings(appPreferences);
  });

  testWidgets('正解の選択肢をタップすると正解表示になる', (tester) async {
    await _pumpScreen(tester, onComplete: () {});

    expect(find.text(_check.question), findsOneWidget);
    expect(find.text(_t('長文読解_1秒チェック_正解')), findsNothing);
    expect(find.text(_t('長文読解_1秒チェック_トップへ戻る')), findsNothing);

    await tester.tap(find.text(_check.optionA));
    await tester.pump();

    expect(find.text(_t('長文読解_1秒チェック_正解')), findsOneWidget);
    expect(find.text(_t('長文読解_1秒チェック_不正解')), findsNothing);
    expect(find.text(_check.explanation), findsOneWidget);
    expect(find.text(_t('長文読解_1秒チェック_トップへ戻る')), findsOneWidget);
  });

  testWidgets('不正解の選択肢をタップすると不正解表示＋正解の選択肢＋解説が出る', (tester) async {
    await _pumpScreen(tester, onComplete: () {});

    await tester.tap(find.text(_check.optionB));
    await tester.pump();

    expect(find.text(_t('長文読解_1秒チェック_不正解')), findsOneWidget);
    expect(
      find.text(
        _t(
          '長文読解_1秒チェック_正解表示',
        ).trFmt(appSettings.language, [_check.correctOption]),
      ),
      findsOneWidget,
    );
    expect(find.text(_check.explanation), findsOneWidget);
  });

  testWidgets('回答後はA/Bどちらのタップにも反応しない（選び直せない）', (tester) async {
    await _pumpScreen(tester, onComplete: () {});

    await tester.tap(find.text(_check.optionA));
    await tester.pump();
    expect(find.text(_t('長文読解_1秒チェック_正解')), findsOneWidget);

    await tester.tap(find.text(_check.optionB));
    await tester.pump();

    // 選び直しはできず、最初の（正解の）判定のまま。
    expect(find.text(_t('長文読解_1秒チェック_正解')), findsOneWidget);
    expect(find.text(_t('長文読解_1秒チェック_不正解')), findsNothing);
  });

  testWidgets('「トップへ戻る」をタップするとonCompleteが呼ばれる', (tester) async {
    var completed = false;
    await _pumpScreen(tester, onComplete: () => completed = true);

    await tester.tap(find.text(_check.optionA));
    await tester.pump();
    expect(completed, isFalse);

    await tester.tap(find.text(_t('長文読解_1秒チェック_トップへ戻る')));
    expect(completed, isTrue);

    // 保留中の自動遷移タイマーが残らないよう、テスト終了前に使い切る。
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('回答から2秒後に自動でonCompleteが呼ばれる', (tester) async {
    var completed = false;
    await _pumpScreen(tester, onComplete: () => completed = true);

    await tester.tap(find.text(_check.optionA));
    await tester.pump();
    expect(completed, isFalse);

    await tester.pump(const Duration(milliseconds: 1900));
    expect(completed, isFalse);

    await tester.pump(const Duration(milliseconds: 200));
    expect(completed, isTrue);
  });
}
