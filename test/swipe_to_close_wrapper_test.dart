import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:osm_gradus/widgets/swipe_to_close_wrapper.dart';

void main() {
  testWidgets('下方向に素早くドラッグして指を離すとonCloseが呼ばれる', (
    WidgetTester tester,
  ) async {
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SwipeToCloseWrapper(
          onClose: () => closed = true,
          child: Container(color: Colors.white),
        ),
      ),
    );

    await tester.fling(find.byType(Container), const Offset(0, 300), 1000);
    await tester.pump();

    expect(closed, isTrue);
  });

  testWidgets('左端から右方向に素早くドラッグして指を離すとonCloseが呼ばれる', (
    WidgetTester tester,
  ) async {
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SwipeToCloseWrapper(
          onClose: () => closed = true,
          child: Container(color: Colors.white),
        ),
      ),
    );

    // 右スワイプは左端スタートのみ有効。
    final gesture = await tester.startGesture(const Offset(16, 300));
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
    await tester.pump();

    expect(closed, isTrue);
  });

  testWidgets('画面中央からの右フリックでは閉じない（左端限定）', (
    WidgetTester tester,
  ) async {
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SwipeToCloseWrapper(
          onClose: () => closed = true,
          child: Container(color: Colors.white),
        ),
      ),
    );

    await tester.fling(find.byType(Container), const Offset(300, 0), 1000);
    await tester.pump();

    expect(closed, isFalse);
  });

  testWidgets('ゆっくりしたドラッグ（速度が閾値未満）ではonCloseが呼ばれない', (
    WidgetTester tester,
  ) async {
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SwipeToCloseWrapper(
          onClose: () => closed = true,
          child: Container(color: Colors.white),
        ),
      ),
    );

    await tester.fling(find.byType(Container), const Offset(0, 300), 50);
    await tester.pump();

    expect(closed, isFalse);
  });

  testWidgets(
    '内側の長押しジェスチャーは、押している間に指がわずかに動いても'
    'キャンセルされず、ジェスチャーアリーナで競合しない（回帰テスト）',
    (WidgetTester tester) async {
      var holdStarted = false;
      var holdEndedNormally = false;
      var holdCancelled = false;
      var closed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SwipeToCloseWrapper(
            onClose: () => closed = true,
            child: Center(
              child: GestureDetector(
                onLongPressStart: (_) => holdStarted = true,
                onLongPressEnd: (_) => holdEndedNormally = true,
                onLongPressCancel: () => holdCancelled = true,
                child: Container(
                  key: const Key('mic'),
                  width: 100,
                  height: 100,
                  color: Colors.red,
                ),
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('mic'))),
      );
      await tester.pump(kLongPressTimeout + kPressTimeout);
      expect(holdStarted, isTrue);

      await gesture.moveBy(const Offset(3, 3));
      await tester.pump();

      await gesture.up();
      await tester.pump();

      expect(holdEndedNormally, isTrue);
      expect(holdCancelled, isFalse);
      expect(closed, isFalse);
    },
  );

  testWidgets(
    '上方向へのフリックにわずかな右方向の速度が混ざっていても、'
    '上方向が支配的なら閉じない（右手親指スクロールの誤検出防止・回帰テスト）',
    (WidgetTester tester) async {
      var closed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: SwipeToCloseWrapper(
            onClose: () => closed = true,
            child: Container(color: Colors.white),
          ),
        ),
      );

      await tester.fling(find.byType(Container), const Offset(80, -300), 1000);
      await tester.pump();

      expect(closed, isFalse);
    },
  );

  testWidgets(
    '下スクロールのあと親指の弧で終点が右寄りになっても閉じない（回帰テスト）',
    (WidgetTester tester) async {
      var closed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: SwipeToCloseWrapper(
            onClose: () => closed = true,
            child: Container(color: Colors.white),
          ),
        ),
      );

      // 画面中央スタート（左端ではない）＋縦に大きく動いてから右へ弧。
      final gesture = await tester.startGesture(const Offset(200, 200));
      await gesture.moveTo(
        const Offset(205, 280),
        timeStamp: const Duration(milliseconds: 30),
      );
      await gesture.moveTo(
        const Offset(210, 380),
        timeStamp: const Duration(milliseconds: 60),
      );
      await gesture.moveTo(
        const Offset(215, 480),
        timeStamp: const Duration(milliseconds: 90),
      );
      await gesture.moveTo(
        const Offset(280, 420),
        timeStamp: const Duration(milliseconds: 200),
      );
      await gesture.moveTo(
        const Offset(340, 360),
        timeStamp: const Duration(milliseconds: 215),
      );
      await gesture.moveTo(
        const Offset(390, 320),
        timeStamp: const Duration(milliseconds: 230),
      );
      await gesture.up(timeStamp: const Duration(milliseconds: 230));
      await tester.pump();

      expect(closed, isFalse);
    },
  );

  testWidgets(
    'スクロール可能なリストを実際にスクロールした指の動きでは閉じない',
    (WidgetTester tester) async {
      var closed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: SwipeToCloseWrapper(
            onClose: () => closed = true,
            child: ListView(
              children: List.generate(
                50,
                (i) => SizedBox(height: 60, child: Text('item $i')),
              ),
            ),
          ),
        ),
      );

      // 下方向へ強くフリック＝リストをスクロール。閉じてはいけない。
      await tester.fling(find.byType(ListView), const Offset(0, 400), 1200);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(closed, isFalse);
    },
  );

  testWidgets(
    '内側のスクロール可能なリストは、SwipeToCloseWrapperに妨げられず通常通りスクロールできる',
    (WidgetTester tester) async {
      var closed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: SwipeToCloseWrapper(
            onClose: () => closed = true,
            child: ListView(
              children: List.generate(
                50,
                (i) => SizedBox(height: 60, child: Text('item $i')),
              ),
            ),
          ),
        ),
      );

      expect(find.text('item 0'), findsOneWidget);
      expect(find.text('item 40'), findsNothing);

      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pump();

      expect(find.text('item 0'), findsNothing);
      expect(closed, isFalse);
    },
  );

  testWidgets(
    '左端からの右スワイプは、内側の横スクロールが反応しても閉じる'
    '（スクロール拒否は下スワイプ専用・回帰テスト）',
    (WidgetTester tester) async {
      var closed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: SwipeToCloseWrapper(
            onClose: () => closed = true,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: List.generate(
                20,
                (i) => SizedBox(width: 120, child: Text('h $i')),
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(20, 300));
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
      await tester.pump();

      expect(closed, isTrue);
    },
  );

  testWidgets(
    'システム端ジェスチャ余白の内側（旧32px帯の外側）からの右スワイプでも閉じる',
    (WidgetTester tester) async {
      var closed = false;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(800, 1200),
            // Androidジェスチャーナビ相当の左端余白。
            systemGestureInsets: EdgeInsets.only(left: 20),
          ),
          child: MaterialApp(
            home: SwipeToCloseWrapper(
              onClose: () => closed = true,
              child: Container(color: Colors.white),
            ),
          ),
        ),
      );

      // contestedLeft(20) + 旧幅32 = 52 を超える x=60 でも、新幅56なら有効。
      final gesture = await tester.startGesture(const Offset(60, 400));
      await gesture.moveBy(
        const Offset(40, 0),
        timeStamp: const Duration(milliseconds: 10),
      );
      await gesture.moveBy(
        const Offset(80, 0),
        timeStamp: const Duration(milliseconds: 20),
      );
      await gesture.moveBy(
        const Offset(100, 0),
        timeStamp: const Duration(milliseconds: 30),
      );
      await gesture.moveBy(
        const Offset(60, 0),
        timeStamp: const Duration(milliseconds: 40),
      );
      await gesture.up(timeStamp: const Duration(milliseconds: 40));
      await tester.pump();

      expect(closed, isTrue);
    },
  );

  testWidgets(
    '左端からの明確な右スワイプがPointerCancelされてもonCloseが呼ばれる'
    '（Android/iPad端ジェスチャ奪取の回帰テスト）',
    (WidgetTester tester) async {
      var closed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: SwipeToCloseWrapper(
            onClose: () => closed = true,
            child: Container(color: Colors.white),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(16, 300));
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
      await gesture.cancel();
      await tester.pump();

      expect(closed, isTrue);
    },
  );

  testWidgets(
    '距離は十分でも中央スタートの右フリックは依然として閉じない',
    (WidgetTester tester) async {
      var closed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: SwipeToCloseWrapper(
            onClose: () => closed = true,
            child: Container(color: Colors.white),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(200, 300));
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
      await gesture.up(timeStamp: const Duration(milliseconds: 30));
      await tester.pump();

      expect(closed, isFalse);
    },
  );
}
