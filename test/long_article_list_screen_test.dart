import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/localization/app_strings.dart';
import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/models/long_article.dart';
import 'package:osm_gradus/models/long_article_comprehension_check.dart';
import 'package:osm_gradus/models/saved_vocabulary_check.dart';
import 'package:osm_gradus/models/vocab_test_session.dart';
import 'package:osm_gradus/models/vocabulary_entry.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/services/long_article_service.dart';
import 'package:osm_gradus/services/vocabulary_check_storage.dart';
import 'package:osm_gradus/views/layers/long_article_comprehension_check_screen.dart';
import 'package:osm_gradus/views/layers/long_article_list_screen.dart';
import 'package:osm_gradus/views/layers/long_article_reader_screen.dart';
import 'package:osm_gradus/views/layers/vocabulary_check_detail_screen.dart';
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

  testWidgets('一覧から開いても、1秒チェックがあればスキップされずに表示される'
      '（読解のみで終わるゾンビ動線が直っている）', (WidgetTester tester) async {
    const check = LongArticleComprehensionCheck(
      question: '誰と旅行に行きましたか？',
      optionA: '友達',
      optionB: '家族',
      correctOption: 'A',
      explanationJa: '本文に「友達と一緒に」とある。',
      explanationEn: 'The text says with a friend.',
      explanationVi: 'Văn bản có ghi cùng bạn.',
    );
    await LongArticleService().addArticle(
      body: '友達と一緒に旅行に行きました。',
      title: '旅行',
      comprehensionCheck: check,
    );
    await _pumpListScreen(tester);

    await tester.tap(find.text('旅行'));
    await tester.pumpAndSettle();
    expect(find.byType(LongArticleReaderScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pumpAndSettle();

    // 読解画面のまま／一覧に即座に戻らず、1秒チェックが挟まる。
    expect(find.byType(LongArticleComprehensionCheckScreen), findsOneWidget);
    expect(find.text('誰と旅行に行きましたか？'), findsOneWidget);
    expect(find.byType(LongArticleListScreen), findsNothing);
  });

  testWidgets('正解率は未実施なら「ー」、実施済みなら四捨五入した%で表示される', (
    WidgetTester tester,
  ) async {
    await LongArticleService().addArticle(body: '本文A', title: '未実施');
    final added = await LongArticleService().addArticle(
      body: '本文B',
      title: '実施済み',
    );
    await LongArticleService().recordVocabTestResult(
      added.first.id,
      correctCount: 8,
      questionCount: 9,
      lastVocabularyCheckId: 'chk_1',
    );
    await _pumpListScreen(tester);

    expect(find.text(_t('長文読解_正解率').replaceFirst('%@', 'ー')), findsOneWidget);
    expect(find.text(_t('長文読解_正解率').replaceFirst('%@', '89%')), findsOneWidget);
  });

  testWidgets('クイズ1＋単語9の合成10問なら正解率は90%（9/10）', (WidgetTester tester) async {
    final added = await LongArticleService().addArticle(
      body: '本文C',
      title: '合成10問',
    );
    await LongArticleService().recordVocabTestResult(
      added.first.id,
      correctCount: 9,
      questionCount: 10,
      lastVocabularyCheckId: 'chk_10',
    );
    await _pumpListScreen(tester);

    expect(find.text(_t('長文読解_正解率').replaceFirst('%@', '90%')), findsOneWidget);
  });

  testWidgets('正解率をタップすると、対応するSavedVocabularyCheckがあれば詳細画面が開く', (
    WidgetTester tester,
  ) async {
    final added = await LongArticleService().addArticle(
      body: '友達と公園へ行きました。',
      title: '旅行',
    );
    await LongArticleService().recordVocabTestResult(
      added.first.id,
      correctCount: 8,
      questionCount: 9,
      lastVocabularyCheckId: 'chk_1',
    );
    await VocabularyCheckStorage().save(
      SavedVocabularyCheck.fromSession(
        id: 'chk_1',
        sessionId: 'sess_1',
        createdAt: DateTime(2026, 1, 1),
        session: VocabTestSession(
          questions: [
            VocabTestQuestion(
              entry: VocabularyEntry(
                id: 'v1',
                word: '観光',
                translation: 'sightseeing',
                createdAt: DateTime(2026, 1, 1),
              ),
              status: VocabTestQuestionStatus.completed,
            ),
          ],
        ),
        longArticleId: added.first.id,
        longArticleTitle: '旅行',
      ),
    );
    await _pumpListScreen(tester);

    await tester.tap(find.text(_t('長文読解_正解率').replaceFirst('%@', '89%')));
    await tester.pumpAndSettle();

    expect(find.byType(VocabularyCheckDetailScreen), findsOneWidget);
    // 一覧の行タップ（読解画面を開く）ではなく、正解率タップだけが反応した。
    expect(find.byType(LongArticleReaderScreen), findsNothing);
  });

  testWidgets('正解率タップ時、記録が見つからなければSnackBarを出し詳細は開かない', (
    WidgetTester tester,
  ) async {
    final added = await LongArticleService().addArticle(
      body: '友達と公園へ行きました。',
      title: '旅行',
    );
    await LongArticleService().recordVocabTestResult(
      added.first.id,
      correctCount: 8,
      questionCount: 9,
      lastVocabularyCheckId: 'missing_check_id',
    );
    await _pumpListScreen(tester);

    await tester.tap(find.text(_t('長文読解_正解率').replaceFirst('%@', '89%')));
    await tester.pumpAndSettle();

    expect(find.byType(VocabularyCheckDetailScreen), findsNothing);
    expect(find.text(_t('長文読解_語彙_結果詳細なし')), findsOneWidget);
  });

  testWidgets('selectionModeでは正解率テキストは独立してタップできず、行タップが選択を優先する', (
    WidgetTester tester,
  ) async {
    final added = await LongArticleService().addArticle(
      body: '友達と公園へ行きました。',
      title: '旅行',
    );
    await LongArticleService().recordVocabTestResult(
      added.first.id,
      correctCount: 8,
      questionCount: 9,
      lastVocabularyCheckId: 'chk_1',
    );
    LongArticle? popped;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              popped = await Navigator.of(context).push<LongArticle?>(
                MaterialPageRoute(
                  builder: (_) =>
                      const LongArticleListScreen(selectionMode: true),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(_t('長文読解_正解率').replaceFirst('%@', '89%')));
    await tester.pumpAndSettle();

    expect(popped?.id, added.first.id);
  });
}
