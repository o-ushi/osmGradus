import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/localization/app_strings.dart';
import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/models/pronunciation_exercise.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/services/pronunciation_exercise_service.dart';
import 'package:osm_gradus/views/layers/pronunciation_exercise_import_screen.dart';

const _lang = 'vi';
String _t(String key) => key.tr(_lang);
String _tFmt(String key, List<String> args) => key.trFmt(_lang, args);

const _validBatchJson = '''
[
  {"category": "tsu", "sentence": "包丁を使います。", "reading": "ほうちょうをつかいます。", "targetExpressions": ["つかいます"], "vietnameseHint": "vi1", "evaluationPoint": "ja1"},
  {"category": "zRow", "sentence": "象がいます。", "reading": "ぞうがいます。", "targetExpressions": ["ぞう"], "vietnameseHint": "vi2", "evaluationPoint": "ja2"}
]''';

/// クリップボードをテスト内で完結するインメモリの偽実装に差し替える
/// （画面のinitStateが自動でクリップボードを読みに行くため、未設定だと
/// FakeAsync下でgetDataが解決しない）。
void _mockClipboard(WidgetTester tester, {String initial = ''}) {
  var clipboardText = initial;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      switch (call.method) {
        case 'Clipboard.getData':
          return {'text': clipboardText};
        case 'Clipboard.setData':
          clipboardText = (call.arguments as Map)['text'] as String? ?? '';
          return null;
        default:
          return null;
      }
    },
  );
}

/// テスト用ビューポートを十分に大きくし、ListView内の全カードが
/// スクロールなしでレイアウト・マウントされるようにする
/// （既定の小さいテストサイズだと、下の方のTextFieldが遅延構築されず
/// enterText()が「見つからない」扱いになるため）。
Future<void> _pumpScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    const MaterialApp(home: PronunciationExerciseImportScreen()),
  );
  await tester.pump();
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

  testWidgets('画面を開くと全カテゴリの取り込み済み件数が0件で表示される', (WidgetTester tester) async {
    _mockClipboard(tester);
    await _pumpScreen(tester);

    expect(find.text(_t('発音課題の取り込み')), findsWidgets);
    expect(find.text(_tFmt('%lld 件', ['0'])), findsNWidgets(5));
  });

  testWidgets('未取り込みのうちに「取り込む」をタップしても何も起こらない（無効化されている）', (
    WidgetTester tester,
  ) async {
    _mockClipboard(tester);
    await _pumpScreen(tester);

    await tester.tap(find.text(_t('取り込む')), warnIfMissed: false);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text(_tFmt('%lld 件', ['0'])), findsNWidgets(5));

    const service = PronunciationExerciseService();
    final total = await service.loadAllImported();
    expect(total, isEmpty);
  });

  testWidgets('AI回答のJSONを貼り付けると取り込み候補がプレビュー表示される', (
    WidgetTester tester,
  ) async {
    _mockClipboard(tester);
    await _pumpScreen(tester);

    await tester.enterText(find.byType(TextField), _validBatchJson);
    await tester.pump();

    expect(find.text(_t('取り込み候補のプレビュー')), findsOneWidget);
    expect(find.text('包丁を使います。'), findsOneWidget);
    expect(find.text('象がいます。'), findsOneWidget);
  });

  testWidgets('取り込むをタップすると保存され、カテゴリ別の件数が更新される', (
    WidgetTester tester,
  ) async {
    _mockClipboard(tester);
    await _pumpScreen(tester);

    await tester.enterText(find.byType(TextField), _validBatchJson);
    await tester.pump();

    await tester.tap(find.text(_t('取り込む')));
    await tester.pump();
    await tester.pump();

    expect(find.text(_t('取り込み候補のプレビュー')), findsNothing);
    expect(tester.takeException(), isNull);

    const service = PronunciationExerciseService();
    final tsuImported = await service.loadImported(PronunciationCategory.tsu);
    expect(tsuImported, hasLength(1));
    expect(tsuImported.single.sentence, '包丁を使います。');

    final zRowImported = await service.loadImported(
      PronunciationCategory.zRow,
    );
    expect(zRowImported, hasLength(1));
    expect(zRowImported.single.sentence, '象がいます。');
  });

  testWidgets('カテゴリ削除を確認すると、そのカテゴリの取り込み済み課題だけが削除される', (
    WidgetTester tester,
  ) async {
    _mockClipboard(tester);
    const service = PronunciationExerciseService();
    await service.importExercises([
      PronunciationExercise(
        id: 'pron_imported_tsu_screen_test',
        category: PronunciationCategory.tsu,
        sentence: 'テスト用の文です。',
        reading: 'てすとようのぶんです。',
        targetExpressions: const ['てすと'],
        vietnameseHint: 'v',
        evaluationPoint: 'e',
        source: PronunciationExerciseSource.imported,
      ),
      PronunciationExercise(
        id: 'pron_imported_zrow_screen_test',
        category: PronunciationCategory.zRow,
        sentence: '象がいます。',
        reading: 'ぞうがいます。',
        targetExpressions: const ['ぞう'],
        vietnameseHint: 'v',
        evaluationPoint: 'e',
        source: PronunciationExerciseSource.imported,
      ),
    ]);

    await _pumpScreen(tester);
    expect(find.text(_tFmt('%lld 件', ['1'])), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pump();
    await tester.tap(find.text(_t('削除')));
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    final tsuImported = await service.loadImported(PronunciationCategory.tsu);
    final zRowImported = await service.loadImported(
      PronunciationCategory.zRow,
    );
    // tsuが先に削除されたか、zRowが先に削除されたかは一覧の並び順に依存するが、
    // どちらか一方だけが0件になり、もう一方は1件のまま残っていることを確認する。
    final counts = [tsuImported.length, zRowImported.length]..sort();
    expect(counts, [0, 1]);
  });
}
