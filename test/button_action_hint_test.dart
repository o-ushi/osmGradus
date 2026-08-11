import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/localization/app_strings.dart';
import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/widgets/button_action_hint.dart';
import 'package:osm_gradus/widgets/ghost_pill.dart';
import 'package:osm_gradus/widgets/transport_icon_button.dart';

const _lang = 'vi';
String _t(String key) => key.tr(_lang);

String _hintMessage(String tapText, {String? longPressText}) =>
    '${'ボタンヒント_タップ'.trFmt(_lang, [tapText])}\n'
    '${'ボタンヒント_長押し'.trFmt(_lang, [longPressText ?? _t('ボタンヒント_長押しなし')])}';

Widget _harness(Widget child) {
  return MaterialApp(
    navigatorObservers: [ButtonActionHintNavigatorObserver()],
    builder: (context, materialChild) =>
        ButtonActionHintOverlay(child: materialChild!),
    home: Scaffold(body: Center(child: child)),
  );
}

/// 本物のダブルタップ（[kDoubleTapMinTime]〜[kDoubleTapTimeout]の間隔）を
/// 送る。連続で`tester.tap`するだけだと間隔が[kDoubleTapMinTime]未満になり
/// 「バウンス」としてダブルタップ判定されないことがあるため、100msだけ空ける。
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

  tearDown(() {
    // Step 8の設定はグローバルなappSettingsに保存されるため、他のテストへ
    // 漏れないよう既定値に戻す。
    appSettings.buttonHintPersistUntilNextAction = false;
    appSettings.buttonHintDisplaySeconds =
        AppPreferences.defaultButtonHintDisplaySeconds;
  });

  testWidgets('単タップは（ダブルタップ判定の待ち時間の後で）本来の動作を1回だけ実行し、ヒントは出ない（Step 7）', (
    tester,
  ) async {
    var tapCount = 0;
    await tester.pumpWidget(
      _harness(
        GhostPill(
          icon: Icons.quiz_outlined,
          onTap: () => tapCount++,
          hintTapText: 'テストアクション',
        ),
      ),
    );

    await tester.tap(find.byType(GhostPill));
    // ダブルタップかもしれない間はまだ発火しない。
    await tester.pump(const Duration(milliseconds: 100));
    expect(tapCount, 0);

    // kDoubleTapTimeout（300ms）を過ぎて、単タップと確定してから発火する。
    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
    expect(tapCount, 1);
    expect(find.text(_hintMessage('テストアクション')), findsNothing);
  });

  testWidgets('ダブルタップでは本来の動作（onTap）は実行されず、ヒントだけが出る（Step 7の本来の目的：'
      'ダイアログ表示・画面遷移するボタンで、1回目のタップの副作用が2回目のタップの到達を'
      '妨げないようにする）', (tester) async {
    var tapCount = 0;
    await tester.pumpWidget(
      _harness(
        GhostPill(
          icon: Icons.quiz_outlined,
          onTap: () => tapCount++,
          hintTapText: 'テストアクション',
        ),
      ),
    );

    await _doubleTap(tester, find.byType(GhostPill));

    expect(tapCount, 0);
    expect(find.text(_hintMessage('テストアクション')), findsOneWidget);
  });

  testWidgets('長押し機能があるボタンでは長押しの説明もヒントに含まれる（Step 7）', (tester) async {
    await tester.pumpWidget(
      _harness(
        TransportIconButton(
          icon: Icons.translate_rounded,
          tooltip: 'テスト',
          visible: true,
          onTap: () {},
          onLongPress: () {},
          hintTapText: 'タップ動作',
          hintLongPressText: '長押し動作',
        ),
      ),
    );

    await _doubleTap(tester, find.byType(TransportIconButton));

    expect(
      find.text(_hintMessage('タップ動作', longPressText: '長押し動作')),
      findsOneWidget,
    );
  });

  testWidgets('表示中に他の場所をタップすると、その操作を妨げず即座に消える（Step 7）', (tester) async {
    await tester.pumpWidget(
      _harness(
        GhostPill(
          icon: Icons.quiz_outlined,
          onTap: () {},
          hintTapText: 'テストアクション',
        ),
      ),
    );

    await _doubleTap(tester, find.byType(GhostPill));
    expect(find.text(_hintMessage('テストアクション')), findsOneWidget);

    // ヒント自体はIgnorePointerで包まれているため、画面の別の場所（GhostPill
    // の外）へのタップは、他ウィジェットへの到達を一切妨げない
    // （[ButtonActionHintOverlayState]のグローバルポインタ監視は消去だけを
    // 行い、イベント自体を消費しないpointerRouterの副読経路のため）。
    await tester.tapAt(const Offset(770, 580));
    await tester.pump();

    expect(find.text(_hintMessage('テストアクション')), findsNothing);
  });

  testWidgets('無操作のまま3秒経つと自動的に消える（Step 7）', (tester) async {
    await tester.pumpWidget(
      _harness(
        GhostPill(
          icon: Icons.quiz_outlined,
          onTap: () {},
          hintTapText: 'テストアクション',
        ),
      ),
    );

    await _doubleTap(tester, find.byType(GhostPill));
    expect(find.text(_hintMessage('テストアクション')), findsOneWidget);

    await tester.pump(const Duration(seconds: 3, milliseconds: 100));

    expect(find.text(_hintMessage('テストアクション')), findsNothing);
  });

  testWidgets('設定の表示期間を変えると、その秒数で自動的に消える（Step 8）', (tester) async {
    appSettings.buttonHintDisplaySeconds = 2;
    await tester.pumpWidget(
      _harness(
        GhostPill(
          icon: Icons.quiz_outlined,
          onTap: () {},
          hintTapText: 'テストアクション',
        ),
      ),
    );

    await _doubleTap(tester, find.byType(GhostPill));
    expect(find.text(_hintMessage('テストアクション')), findsOneWidget);

    // 既定の3秒はまだ経っていないが、設定した2秒はもう経っている。
    await tester.pump(const Duration(seconds: 2, milliseconds: 100));

    expect(find.text(_hintMessage('テストアクション')), findsNothing);
  });

  testWidgets('「次のアクションまで表示」ONの間は時間が経っても消えず、他操作で消える（Step 8）', (tester) async {
    appSettings.buttonHintPersistUntilNextAction = true;
    await tester.pumpWidget(
      _harness(
        GhostPill(
          icon: Icons.quiz_outlined,
          onTap: () {},
          hintTapText: 'テストアクション',
        ),
      ),
    );

    await _doubleTap(tester, find.byType(GhostPill));
    expect(find.text(_hintMessage('テストアクション')), findsOneWidget);

    // 既定はもちろん、それよりずっと長く待っても時間では消えない。
    await tester.pump(const Duration(seconds: 10));
    expect(find.text(_hintMessage('テストアクション')), findsOneWidget);

    await tester.tapAt(const Offset(770, 580));
    await tester.pump();
    expect(find.text(_hintMessage('テストアクション')), findsNothing);
  });

  testWidgets('hintTapTextを指定しないボタンは単タップが遅延せず即座に反応する（既存挙動を壊さない）', (
    tester,
  ) async {
    var tapCount = 0;
    await tester.pumpWidget(
      _harness(GhostPill(icon: Icons.quiz_outlined, onTap: () => tapCount++)),
    );

    await tester.tap(find.byType(GhostPill));
    await tester.pump();
    expect(tapCount, 1);

    await tester.tap(find.byType(GhostPill));
    await tester.pump();
    expect(tapCount, 2);
    expect(find.textContaining('：'), findsNothing);
  });
}
