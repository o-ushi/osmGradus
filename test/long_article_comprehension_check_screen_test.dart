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
  explanationJa: '本文に「友達と一緒に」とある。',
  explanationEn: 'The text says "with a friend."',
  explanationVi: 'Văn bản có ghi "cùng với bạn bè".',
);

Future<void> _pumpScreen(
  WidgetTester tester, {
  required ValueChanged<String> onComplete,
  LongArticleComprehensionCheck check = _check,
  bool continuesToVocabTest = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: LongArticleComprehensionCheckScreen(
        check: check,
        onComplete: onComplete,
        continuesToVocabTest: continuesToVocabTest,
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
    await _pumpScreen(tester, onComplete: (_) {});

    expect(find.text(_check.question), findsOneWidget);
    expect(find.text(_t('長文読解_1秒チェック_正解')), findsNothing);
    expect(find.text(_t('長文読解_1秒チェック_トップへ戻る')), findsNothing);

    await tester.tap(find.text(_check.optionA));
    await tester.pump();

    expect(find.text(_t('長文読解_1秒チェック_正解')), findsOneWidget);
    expect(find.text(_t('長文読解_1秒チェック_不正解')), findsNothing);
    expect(
      find.text(_check.explanationFor(appSettings.language)),
      findsOneWidget,
    );
    expect(find.text(_t('長文読解_1秒チェック_トップへ戻る')), findsOneWidget);
  });

  testWidgets('不正解の選択肢をタップすると不正解表示＋正解の選択肢＋解説が出る', (tester) async {
    await _pumpScreen(tester, onComplete: (_) {});

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
    expect(
      find.text(_check.explanationFor(appSettings.language)),
      findsOneWidget,
    );
  });

  testWidgets('回答後はA/Bどちらのタップにも反応しない（選び直せない）', (tester) async {
    await _pumpScreen(tester, onComplete: (_) {});

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
    await _pumpScreen(tester, onComplete: (_) => completed = true);

    await tester.tap(find.text(_check.optionA));
    await tester.pump();
    expect(completed, isFalse);

    await tester.tap(find.text(_t('長文読解_1秒チェック_トップへ戻る')));
    expect(completed, isTrue);
  });

  testWidgets('continuesToVocabTest:trueのときは「トップへ戻る」ではなく'
      '「語彙テストへ進む」と表示される（Step 10：語彙テストが続くのに'
      '「トップへ戻る」のままだった文言不整合の回帰）', (tester) async {
    var completed = false;
    await _pumpScreen(
      tester,
      onComplete: (_) => completed = true,
      continuesToVocabTest: true,
    );

    await tester.tap(find.text(_check.optionA));
    await tester.pump();

    expect(find.text(_t('長文読解_1秒チェック_トップへ戻る')), findsNothing);
    expect(find.text(_t('長文読解_1秒チェック_語彙テストへ')), findsOneWidget);

    await tester.tap(find.text(_t('長文読解_1秒チェック_語彙テストへ')));
    expect(completed, isTrue);
  });

  testWidgets('回答しても自動では戻らない（タップするまで待つ）', (tester) async {
    var completed = false;
    await _pumpScreen(tester, onComplete: (_) => completed = true);

    await tester.tap(find.text(_check.optionA));
    await tester.pump();
    expect(completed, isFalse);

    // 解説を読む時間は学習者ごとに違うため、時間が経っても自動遷移しない。
    await tester.pump(const Duration(seconds: 10));
    expect(completed, isFalse);
  });

  group('解説の表示言語', () {
    tearDown(() => appSettings.language = AppPreferences.defaultLanguage);

    testWidgets('appSettings.languageがjaなら日本語の解説が表示される', (tester) async {
      appSettings.language = 'ja';
      await _pumpScreen(tester, onComplete: (_) {});

      await tester.tap(find.text(_check.optionA));
      await tester.pump();

      expect(find.text(_check.explanationJa), findsOneWidget);
      expect(find.text(_check.explanationEn), findsNothing);
      expect(find.text(_check.explanationVi), findsNothing);
    });

    testWidgets('appSettings.languageがenなら英語の解説が表示される', (tester) async {
      appSettings.language = 'en';
      await _pumpScreen(tester, onComplete: (_) {});

      await tester.tap(find.text(_check.optionA));
      await tester.pump();

      expect(find.text(_check.explanationEn), findsOneWidget);
      expect(find.text(_check.explanationJa), findsNothing);
      expect(find.text(_check.explanationVi), findsNothing);
    });

    testWidgets('appSettings.languageがviならベトナム語の解説が表示される', (tester) async {
      appSettings.language = 'vi';
      await _pumpScreen(tester, onComplete: (_) {});

      await tester.tap(find.text(_check.optionA));
      await tester.pump();

      expect(find.text(_check.explanationVi), findsOneWidget);
      expect(find.text(_check.explanationJa), findsNothing);
      expect(find.text(_check.explanationEn), findsNothing);
    });
  });
}
