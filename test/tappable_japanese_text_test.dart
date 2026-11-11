import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osm_gradus/localization/app_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/models/long_article_word_selection_mode.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/services/vocabulary_service.dart';
import 'package:osm_gradus/theme/app_colors.dart';
import 'package:osm_gradus/widgets/tappable_japanese_text.dart';

const _text = '友達と公園へ行った。';

Future<TappableJapaneseTextState> _pumpText(WidgetTester tester) async {
  final registered = <String>[];
  final unregistered = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TappableJapaneseText(
          text: _text,
          onWordRegistered: registered.add,
          onWordUnregistered: unregistered.add,
        ),
      ),
    ),
  );
  await tester.pump();
  return tester.state<TappableJapaneseTextState>(
    find.byType(TappableJapaneseText),
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    appPreferences = await AppPreferences.load();
    appSettings = AppSettings(appPreferences);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appSettings.longArticleWordSelectionMode =
        LongArticleWordSelectionMode.character;
  });

  testWidgets('タップは選択方式の設定に関わらず常に1チャンクを即座に登録する', (WidgetTester tester) async {
    final state = await _pumpText(tester);
    // '友達'(2文字)+'と'(1文字)+'公園'(2文字)+... の先頭チャンクは'友達'。
    expect(state.debugChunks.first, '友達');

    final topLeft = tester.getTopLeft(find.byType(TappableJapaneseText));
    await tester.tapAt(topLeft + const Offset(6, 10));
    await tester.pump();

    final entries = await VocabularyService().loadEntries();
    expect(entries, hasLength(1));
    expect(entries.single.word, '友達');
  });

  testWidgets('文字単位（既定）: 長押し＋ドラッグは1文字ずつヒットテストし、複数文字をまたいだ範囲を1語として登録する', (
    WidgetTester tester,
  ) async {
    final state = await _pumpText(tester);
    expect(
      appSettings.longArticleWordSelectionMode,
      LongArticleWordSelectionMode.character,
    );
    // 文字単位: ['友','達','と','公','園',...]（チャンク['友達','と',...]より細かい）。
    expect(state.debugHitUnits.take(3), ['友', '達', 'と']);

    // 「友」(0)から「と」(2)までドラッグして選択したことにする。
    state.debugSelectRange(0, 2);
    await tester.pump();

    final entries = await VocabularyService().loadEntries();
    expect(entries, hasLength(1));
    expect(entries.single.word, '友達と');
  });

  testWidgets('文字単位（既定）: ドラッグせず長押しだけなら1文字だけが登録される', (
    WidgetTester tester,
  ) async {
    final state = await _pumpText(tester);
    state.debugSelectRange(0, 0);
    await tester.pump();

    final entries = await VocabularyService().loadEntries();
    expect(entries, hasLength(1));
    expect(entries.single.word, '友');
  });

  testWidgets('文字単位: チャンク途中の1文字登録でも橙色ハイライトが付く', (WidgetTester tester) async {
    final state = await _pumpText(tester);
    state.debugSelectRange(0, 0); // '友'（チャンク「友達」の先頭だけ）
    await tester.pumpAndSettle();

    expect(state.debugRegisteredHitUnitIndices, {0});

    final richText = tester.widget<RichText>(
      find.descendant(
        of: find.byType(TappableJapaneseText),
        matching: find.byType(RichText),
      ),
    );
    // Text.rich は渡した TextSpan をさらに1段ラップするため、実体の文字
    // スパンはその内側の children にある。
    final root = richText.text as TextSpan;
    final paragraph = root.children!.single as TextSpan;
    final spans = paragraph.children!.cast<TextSpan>();
    final orange = AppColors.current.cardAccent.withValues(alpha: 0.35);
    expect(spans[0].text, '友');
    expect(spans[0].style?.backgroundColor, orange);
    expect(spans[0].style?.fontWeight, FontWeight.bold);
    expect(spans[1].style?.backgroundColor, isNull);
  });

  testWidgets('文字単位: チャンクをまたぐ範囲登録でも橙色ハイライトが付く', (WidgetTester tester) async {
    final state = await _pumpText(tester);
    state.debugSelectRange(0, 2); // '友達と'
    await tester.pumpAndSettle();

    expect(state.debugRegisteredHitUnitIndices, {0, 1, 2});
  });

  testWidgets('単語帳から削除したあとに再読込すると橙色ハイライトが消える', (WidgetTester tester) async {
    final unregistered = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TappableJapaneseText(
            text: _text,
            onWordRegistered: (_) {},
            onWordUnregistered: unregistered.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final state = tester.state<TappableJapaneseTextState>(
      find.byType(TappableJapaneseText),
    );

    state.debugSelectRange(0, 1); // '友達'
    await tester.pumpAndSettle();
    expect(state.debugRegisteredHitUnitIndices, {0, 1});

    final entries = await VocabularyService().loadEntries();
    expect(entries, hasLength(1));
    await VocabularyService().deleteEntry(entries.single.id);
    await state.reloadRegisteredWords();
    await tester.pump();

    expect(state.debugRegisteredHitUnitIndices, isEmpty);
    expect(unregistered, [entries.single.id]);
  });

  testWidgets('チャンク単位に切り替えると、長押しだけでチャンク全体が登録される', (WidgetTester tester) async {
    appSettings.longArticleWordSelectionMode =
        LongArticleWordSelectionMode.chunk;
    final state = await _pumpText(tester);
    expect(state.debugHitUnits, state.debugChunks);

    state.debugSelectRange(0, 0);
    await tester.pump();

    final entries = await VocabularyService().loadEntries();
    expect(entries, hasLength(1));
    expect(entries.single.word, '友達');
  });

  testWidgets('登録済みの範囲を長押しすると登録を取り消せる（ドラッグ不要）', (WidgetTester tester) async {
    final state = await _pumpText(tester);
    state.debugSelectRange(0, 1); // 文字単位で'友','達'をまたぐ範囲＝'友達'を登録
    await tester.pump();
    expect(await VocabularyService().loadEntries(), hasLength(1));

    // 実際のジェスチャー経路で、登録範囲内（'友達'の位置）を長押しする。
    final topLeft = tester.getTopLeft(find.byType(TappableJapaneseText));
    await tester.longPressAt(topLeft + const Offset(6, 10));
    await tester.pump();

    expect(await VocabularyService().loadEntries(), isEmpty);
  });

  testWidgets('表示前から単語帳にあった語は、その位置を長押ししても削除されない', (WidgetTester tester) async {
    // 事前に単語帳へ登録しておく（このウィジェットが登録したものではない）。
    await VocabularyService().addEntry('友達', '');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TappableJapaneseText(text: _text, onWordRegistered: (_) {}),
        ),
      ),
    );
    await tester.pump();

    final topLeft = tester.getTopLeft(find.byType(TappableJapaneseText));
    await tester.longPressAt(topLeft + const Offset(6, 10));
    await tester.pump();

    // 表示前からのエントリ（このウィジェットが登録したものではない）は、
    // 長押しのキャンセル対象にならないため削除されない。文字単位の既定
    // モードでは、ドラッグなしの長押しはその1文字を新規登録しうるが、
    // それは既存の'友達'エントリとは別物であり保護の対象外。
    final words = (await VocabularyService().loadEntries()).map((e) => e.word);
    expect(words, contains('友達'));
  });

  testWidgets('前回登録した語も、長押しして確認すると削除でき、候補からも外れる', (WidgetTester tester) async {
    await VocabularyService().addEntry('友達', '');
    final unregistered = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TappableJapaneseText(
            text: _text,
            onWordRegistered: (_) {},
            onWordUnregistered: unregistered.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final topLeft = tester.getTopLeft(find.byType(TappableJapaneseText));
    await tester.longPressAt(topLeft + const Offset(6, 10));
    await tester.pumpAndSettle();
    expect(await VocabularyService().loadEntries(), hasLength(1));

    await tester.tap(
      find.widgetWithText(TextButton, '削除'.tr(appSettings.language)),
    );
    await tester.pumpAndSettle();
    expect(await VocabularyService().loadEntries(), isEmpty);
    expect(unregistered, hasLength(1));
  });

  testWidgets('単語帳に無くなった語のIDは、読み込み時に候補から外れる', (WidgetTester tester) async {
    final unregistered = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TappableJapaneseText(
            text: _text,
            onWordRegistered: (_) {},
            onWordUnregistered: unregistered.add,
            trackedEntryIds: const ['gone'],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(unregistered, ['gone']);
  });

  testWidgets('実ジェスチャー：長押し開始→ドラッグ→離すで範囲登録できる', (WidgetTester tester) async {
    // 1行に収まるよう十分に幅広いビューポートにする。
    tester.view.physicalSize = const Size(1200, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpText(tester);

    final topLeft = tester.getTopLeft(find.byType(TappableJapaneseText));
    final gesture = await tester.startGesture(topLeft + const Offset(6, 10));
    await tester.pump(const Duration(milliseconds: 600));
    // 十分右へ動かし、複数チャンクにまたがる選択にする。
    await gesture.moveTo(topLeft + const Offset(80, 10));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    final entries = await VocabularyService().loadEntries();
    expect(entries, hasLength(1));
    // 少なくとも先頭の'友達'を含む範囲が登録されているはず。
    expect(entries.single.word, startsWith('友達'));
  });
}
