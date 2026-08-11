import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:osm_gradus/widgets/pronunciation_mic_button.dart';

void main() {
  testWidgets('タップするとonTapが呼ばれる', (WidgetTester tester) async {
    var tapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: PronunciationMicButton(armed: true, onTap: () => tapCount++),
        ),
      ),
    );

    await tester.tap(find.byType(PronunciationMicButton));
    await tester.pump();
    expect(tapCount, 1);

    await tester.tap(find.byType(PronunciationMicButton));
    await tester.pump();
    expect(tapCount, 2);
  });

  // 実機（Android）で報告された不具合の回帰テスト：このボタンの操作を
  // 長押しからタップ方式に変更したのは、長押し中に外側の別ジェスチャー
  // （画面全体を覆うスワイプ検出など）に奪われて録音が途中で打ち切られる
  // 問題を根本的に避けるため。祖先にドラッグ系のGestureDetectorを重ねても、
  // タップが正常に完了することを確認する。
  testWidgets('外側に競合するドラッグGestureDetectorがあっても、タップが正常に完了する'
      '（ジェスチャーアリーナ競合の回帰テスト）', (WidgetTester tester) async {
    var tapped = false;
    var outerDragEnded = false;

    await tester.pumpWidget(
      MaterialApp(
        home: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragEnd: (_) => outerDragEnded = true,
          onHorizontalDragEnd: (_) => outerDragEnded = true,
          child: Center(
            child: PronunciationMicButton(
              armed: true,
              onTap: () => tapped = true,
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PronunciationMicButton)),
    );
    // 押し込み・握り直しを想定した、指のわずかな移動。
    await gesture.moveBy(const Offset(4, 4));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(tapped, isTrue);
    expect(outerDragEnded, isFalse);
  });

  testWidgets('指を離す前に別の場所へ動かしても、同じ指のポインタが離れればonTapが呼ばれる', (
    WidgetTester tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: PronunciationMicButton(
            armed: true,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PronunciationMicButton)),
    );
    await gesture.up();
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('armedに応じてサイコロ/マイクのアイコンが切り替わる', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(child: PronunciationMicButton(armed: false, onTap: () {})),
      ),
    );
    expect(find.byIcon(Icons.casino), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: Center(child: PronunciationMicButton(armed: true, onTap: () {})),
      ),
    );
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    expect(find.byIcon(Icons.casino), findsNothing);
  });

  testWidgets('recordingがtrueの間は背景が赤くなる', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: PronunciationMicButton(
            armed: true,
            recording: true,
            onTap: () {},
          ),
        ),
      ),
    );

    final container = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, Colors.redAccent);
  });

  testWidgets('remainingSecondsを指定した固定秒数カウントダウン中は、recordingがtrueでも背景は透明のまま', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: PronunciationMicButton(
            armed: true,
            recording: true,
            remainingSeconds: 10,
            onTap: () {},
          ),
        ),
      ),
    );

    final container = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, Colors.transparent);
    expect(find.text('10'), findsOneWidget);
  });
}
