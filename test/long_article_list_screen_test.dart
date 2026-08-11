import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/localization/app_strings.dart';
import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/services/long_article_service.dart';
import 'package:osm_gradus/views/layers/long_article_list_screen.dart';
import 'package:osm_gradus/views/layers/long_article_reader_screen.dart';
import 'package:osm_gradus/widgets/tappable_japanese_text.dart';

String _t(String key) => key.tr(appSettings.language);

/// 「次へ」等、ダブルタップの機能ヒントが付いたボタン（Step 7）は
/// GestureDetector.onDoubleTapで単タップ判定を約300ms（kDoubleTapTimeout）
/// 保留するため、単タップとして確定させるにはこの分だけ余分にpumpする。
const _tapConfirmWait = Duration(milliseconds: 350);

Future<void> _pumpListScreen(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: LongArticleListScreen()));
  await tester.pump();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    appPreferences = await AppPreferences.load();
    appSettings = AppSettings(appPreferences);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('保存済みの長文が無いと空状態メッセージを表示する', (WidgetTester tester) async {
    await _pumpListScreen(tester);

    expect(find.text(_t('長文読解_一覧が空です')), findsOneWidget);
  });

  testWidgets('保存済みの長文をタイトル・抜粋・日時つきで一覧表示する', (WidgetTester tester) async {
    await LongArticleService().addArticle(body: '友達と公園へ行きました。', title: '旅行');
    await _pumpListScreen(tester);

    expect(find.text('旅行'), findsOneWidget);
    expect(find.textContaining('友達と公園へ行きました'), findsOneWidget);
    // お気に入りは未設定なので枠線の星。
    expect(find.byIcon(Icons.star_border), findsOneWidget);
    expect(find.byIcon(Icons.star), findsNothing);
  });

  testWidgets('★をタップするとお気に入りが切り替わり、永続化される', (WidgetTester tester) async {
    final added = await LongArticleService().addArticle(
      body: '友達と公園へ行きました。',
      title: '旅行',
    );
    await _pumpListScreen(tester);

    await tester.tap(find.byIcon(Icons.star_border));
    await tester.pump();

    expect(find.byIcon(Icons.star), findsOneWidget);
    final articles = await LongArticleService().loadArticles();
    expect(
      articles.firstWhere((a) => a.id == added.single.id).isFavorite,
      isTrue,
    );
  });

  testWidgets('削除アイコン→キャンセルでは削除されず、削除確定で一覧・永続化から消える', (
    WidgetTester tester,
  ) async {
    await LongArticleService().addArticle(body: '友達と公園へ行きました。', title: '旅行');
    await _pumpListScreen(tester);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('キャンセル')));
    await tester.pumpAndSettle();

    expect(find.text('旅行'), findsOneWidget);
    expect(await LongArticleService().loadArticles(), hasLength(1));

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('削除')));
    await tester.pumpAndSettle();

    expect(find.text('旅行'), findsNothing);
    expect(find.text(_t('長文読解_一覧が空です')), findsOneWidget);
    expect(await LongArticleService().loadArticles(), isEmpty);
  });

  testWidgets('タップすると読解画面が開いて単語登録でき、「次へ」で一覧に戻る（長文は複製されない）', (
    WidgetTester tester,
  ) async {
    await LongArticleService().addArticle(body: '友達と公園へ行きました。', title: '旅行');
    await _pumpListScreen(tester);

    await tester.tap(find.text('旅行'));
    await tester.pumpAndSettle();

    expect(find.byType(LongArticleReaderScreen), findsOneWidget);
    expect(find.textContaining('友達と公園へ行きました'), findsWidgets);

    final textTopLeft = tester.getTopLeft(find.byType(TappableJapaneseText));
    await tester.tapAt(textTopLeft + const Offset(6, 10));
    await tester.pump();
    expect(
      (await LongArticleService().loadArticles()).single.body,
      '友達と公園へ行きました。',
    );

    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pumpAndSettle();

    // 一覧画面に戻り、長文は複製されず1件のまま。
    expect(find.byType(LongArticleListScreen), findsOneWidget);
    expect(find.byType(LongArticleReaderScreen), findsNothing);
    expect(await LongArticleService().loadArticles(), hasLength(1));
  });
}
