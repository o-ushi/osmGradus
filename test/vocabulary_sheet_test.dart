import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/localization/app_strings.dart';
import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/models/vocabulary_level.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/services/jlpt_vocab_bank_service.dart';
import 'package:osm_gradus/services/topic_speech_reader.dart';
import 'package:osm_gradus/services/tts_settings_service.dart';
import 'package:osm_gradus/services/vocabulary_service.dart';
import 'package:osm_gradus/theme/app_colors.dart';
import 'package:osm_gradus/widgets/vocabulary_sheet.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    appPreferences = await AppPreferences.load();
    appSettings = AppSettings(appPreferences);
    ttsSettings = TtsSettingsService();
    topicSpeechReader = TopicSpeechReader(ttsSettings);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({
      AppPreferences.includeDefaultVocabularyKey: false,
    });
    appSettings.includeDefaultVocabulary = false;
  });

  test('標準語彙を削除すると単語帳・単語テストの両方から消える', () async {
    final service = VocabularyService();
    const builtinId = 'builtin:n1:概念';
    await service.hideBuiltinEntry(builtinId);

    final visibleEntries = JlptVocabBankService.mergeWithDefaults(
      await service.loadEntries(),
      includeDefaults: true,
      hiddenBuiltinIds: await service.loadHiddenBuiltinIds(),
    );
    expect(visibleEntries.any((entry) => entry.id == builtinId), isFalse);

    final examPool = await JlptVocabBankService().loadExamPool(
      levels: {VocabularyLevel.n1},
      includeDefaults: true,
    );
    expect(examPool.any((entry) => entry.id == builtinId), isFalse);
  });

  // VocabularySheetは`_isShowing`という静的フラグでダイアログの多重起動を
  // 防いでおり、ダイアログを閉じる（showGeneralDialogのFutureが完了する）まで
  // 次のshow()が無視される。そのため、各テストは最後に必ず閉じるボタン
  // （Icons.close_rounded）をタップしてこのフラグをリセットしてから終わる。
  testWidgets('新規登録でN1/N2/N3/Otherレベルを選べ、未選択ならOther、'
      '編集画面では登録済みレベルが選択済み表示になる', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => VocabularySheet.show(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 1件目：N1を選んで登録する。
    await tester.tap(find.text('単語帳_新しい単語'.tr(appSettings.language)));
    await tester.pumpAndSettle();
    // TextFieldの並びは 単語(0)/読み方(1)/例文(2)/訳(3)。
    await tester.enterText(find.byType(TextField).at(0), '概念');
    await tester.enterText(find.byType(TextField).at(1), 'がいねん');
    await tester.enterText(find.byType(TextField).at(3), 'khái niệm');
    await tester.tap(find.text('N1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pumpAndSettle();

    var entries = await VocabularyService().loadEntries();
    expect(entries, hasLength(1));
    expect(entries.single.word, '概念');
    expect(entries.single.reading, 'がいねん');
    expect(entries.single.translation, 'khái niệm');
    expect(entries.single.level, VocabularyLevel.n1);

    // 2件目：レベルを選ばずに登録すると既定でOther（未指定）になる
    // （直前の送信でパネルの状態がリセットされていることも合わせて確認）。
    await tester.tap(find.text('単語帳_新しい単語'.tr(appSettings.language)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'テスト');
    await tester.enterText(find.byType(TextField).at(3), 'test');
    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pumpAndSettle();

    entries = await VocabularyService().loadEntries();
    expect(entries, hasLength(2));
    final untaggedEntry = entries.firstWhere((e) => e.word == 'テスト');
    expect(untaggedEntry.level, VocabularyLevel.other);

    // 管理リストへ切り替え、N1で登録した語（概念）の行を左スワイプして
    // 編集・削除ボタンを出してから、編集ボタンを狙って押す
    // （新規追加は先頭に挿入されるため、一覧の並び順に依存せず
    // ValueKey(entry.id)で対象の行を特定する）。
    final n1EntryId = entries.firstWhere((e) => e.word == '概念').id;
    await tester.tap(find.byIcon(Icons.format_list_bulleted_rounded));
    await tester.pumpAndSettle();

    // スワイプ前は編集・削除ボタンは表示されておらずタップも効かない
    // （行の裏に常時全幅で置いてカードの半透明度だけで隠していた実装では、
    // 半透明カード越しにボタンが透けて見えてしまう回帰があった）。
    await tester.tap(
      find.descendant(
        of: find.byKey(ValueKey(n1EntryId)),
        matching: find.byIcon(Icons.edit_rounded),
      ),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '概念'), findsNothing);

    // 左スワイプすると編集・削除ボタンが現れ、編集ボタンを狙って押すと
    // 編集パネルが開く。
    await tester.drag(find.byKey(ValueKey(n1EntryId)), const Offset(-150, 0));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(ValueKey(n1EntryId)),
        matching: find.byIcon(Icons.edit_rounded),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, '概念'), findsOneWidget);
    expect(_isLevelSegmentSelected(tester, 'N1'), isTrue);

    // 次のテストが`VocabularySheet.show()`を呼べるよう、`_isShowing`静的
    // フラグをリセットするために明示的に閉じておく。
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
  });

  testWidgets('focusEntryIdを指定すると、そのエントリのカードを開いた直後に表示する'
      '（例：出題中の「促進」を単語帳から開いたら「促進」が見える）', (WidgetTester tester) async {
    final service = VocabularyService();
    // 新規追加は先頭に挿入されるため、間に別の語を挟んで「促進」が
    // 既定の先頭（0ページ目）ではないことを保証する。
    await service.addEntry('単語A', 'a');
    final afterPromote = await service.addEntry('促進', 'thúc đẩy');
    await service.addEntry('単語B', 'b');
    final targetId = afterPromote.firstWhere((e) => e.word == '促進').id;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () =>
                    VocabularySheet.show(context, focusEntryId: targetId),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('促進'), findsOneWidget);

    // 次のテストが`VocabularySheet.show()`を呼べるよう、`_isShowing`静的
    // フラグをリセットするために明示的に閉じておく。
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
  });

  testWidgets('フラッシュカードを長押しすると、その語の編集パネルが開く', (WidgetTester tester) async {
    await VocabularyService().addEntry(
      '概念',
      'khái niệm',
      reading: 'がいねん',
      level: VocabularyLevel.n1,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => VocabularySheet.show(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // デッキ表示（フラッシュカード）中に長押しすると、そのまま編集パネルが
    // 開き、登録済みの内容が入力欄に反映されている。
    await tester.longPress(find.text('概念'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, '概念'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'がいねん'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'khái niệm'), findsOneWidget);
    expect(_isLevelSegmentSelected(tester, 'N1'), isTrue);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
  });

  testWidgets('標準語彙のフラッシュカードを長押しして編集できる', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      AppPreferences.includeDefaultVocabularyKey: true,
    });
    appSettings.includeDefaultVocabulary = true;
    addTearDown(() => appSettings.includeDefaultVocabulary = false);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => VocabularySheet.show(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 標準語彙（先頭カード、標準N1の先頭語「概念」）も編集パネルで変更できる。
    await tester.longPress(find.text('概念'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, '概念'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), '概念（編集）');
    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pumpAndSettle();

    final entries = await VocabularyService().loadEntries();
    expect(entries.single.word, '概念（編集）');
    expect(
      await VocabularyService().loadHiddenBuiltinIds(),
      contains('builtin:n1:概念'),
    );

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
  });

  testWidgets('狭い画面・英語表示（"N1"+"Built-in"バッジ）でも一覧表示がオーバーフローしない', (
    WidgetTester tester,
  ) async {
    // 実機幅（iPhone標準的な論理390pt相当）で再現する。デフォルトのテスト
    // ビューポート（800×600相当）は十分広く、この崩れを再現できない。
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final originalLang = appSettings.language;
    appSettings.language = 'en';
    addTearDown(() => appSettings.language = originalLang);
    appSettings.includeDefaultVocabulary = true;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => VocabularySheet.show(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 一覧表示（"N1"＋"Built-in"バッジが並ぶ行）に切り替える。
    await tester.tap(find.byIcon(Icons.format_list_bulleted_rounded));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
  });

  testWidgets('ユーザーが自分で追加した「その他」レベルの語も、一覧表示で'
      'レベルバッジ（Other）が付く', (WidgetTester tester) async {
    await VocabularyService().addEntry('あかさ', 'akasa');

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => VocabularySheet.show(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.format_list_bulleted_rounded));
    await tester.pumpAndSettle();

    expect(find.text('単語帳_レベルその他'.tr(appSettings.language)), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
  });

  testWidgets('単語帳は右スワイプでは閉じず、×ボタンでのみ閉じる', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => VocabularySheet.show(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await _rightSwipeFrom(tester, const Offset(4, 300));
    await tester.pumpAndSettle();
    expect(find.byType(VocabularySheet), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(VocabularySheet), findsNothing);
  });
}

/// 画面左端付近の[start]から右方向へフリックする
/// （かつての[SwipeToCloseWrapper]の右スワイプ判定に必要な速度・距離を満たす。
/// 単語帳はこのジェスチャーでは閉じなくなったことの確認に使う）。
Future<void> _rightSwipeFrom(WidgetTester tester, Offset start) async {
  final gesture = await tester.startGesture(start);
  await gesture.moveBy(
    const Offset(40, 0),
    timeStamp: const Duration(milliseconds: 10),
  );
  await gesture.moveBy(
    const Offset(80, 0),
    timeStamp: const Duration(milliseconds: 20),
  );
  await gesture.moveBy(
    const Offset(120, 0),
    timeStamp: const Duration(milliseconds: 30),
  );
  await gesture.moveBy(
    const Offset(60, 0),
    timeStamp: const Duration(milliseconds: 40),
  );
  await gesture.up(timeStamp: const Duration(milliseconds: 40));
}

/// レベル選択行（`_LevelSegmentedRow`）は等幅制約を避けるため
/// [SegmentedButton]ではなく自前のピルで実装しており、選択状態は
/// [SegmentedButton.selected]のような公開プロパティで読めない。かわりに
/// [label]のセグメントが選択色（[AppPalette.accentColor]）で塗られているかで
/// 判定する。
bool _isLevelSegmentSelected(WidgetTester tester, String label) {
  final finder = find.ancestor(
    of: find.text(label),
    matching: find.byType(Material),
  );
  final material = tester.widget<Material>(finder.first);
  return material.color == AppColors.current.accentColor;
}
