import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/widgets/vocab_countdown_button.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    appPreferences = await AppPreferences.load();
    appSettings = AppSettings(appPreferences);
  });

  group('VocabCountdownButton', () {
    testWidgets('10→0まで1秒ごとに残秒が減っていく', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VocabCountdownButton(
              onTapEarlyFinish: () {},
              onCountdownZero: () {},
            ),
          ),
        ),
      );

      final state = tester.state<VocabCountdownButtonState>(
        find.byType(VocabCountdownButton),
      );
      expect(state.debugRemainingSeconds, 10);
      expect(find.text('10'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(state.debugRemainingSeconds, 9);
      expect(find.text('9'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(state.debugRemainingSeconds, 8);
    });

    testWidgets('0秒到達でonCountdownZeroが呼ばれ、タイマーが止まる', (tester) async {
      var zeroCalled = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VocabCountdownButton(
              seconds: 2,
              onTapEarlyFinish: () {},
              onCountdownZero: () => zeroCalled++,
            ),
          ),
        ),
      );

      final state = tester.state<VocabCountdownButtonState>(
        find.byType(VocabCountdownButton),
      );

      await tester.pump(const Duration(seconds: 1));
      expect(zeroCalled, 0);
      expect(state.debugIsRunning, isTrue);

      await tester.pump(const Duration(seconds: 1));
      expect(zeroCalled, 1);
      expect(state.debugRemainingSeconds, 0);
      expect(state.debugIsRunning, isFalse);

      // 0秒到達後はタイマーが止まっているので、さらに待っても増えない。
      await tester.pump(const Duration(seconds: 3));
      expect(zeroCalled, 1);
    });

    testWidgets('タップすると残秒に関係なくonTapEarlyFinishが呼ばれ、以降は0秒到達にならない', (
      tester,
    ) async {
      var earlyFinishCalled = 0;
      var zeroCalled = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VocabCountdownButton(
              onTapEarlyFinish: () => earlyFinishCalled++,
              onCountdownZero: () => zeroCalled++,
            ),
          ),
        ),
      );

      final state = tester.state<VocabCountdownButtonState>(
        find.byType(VocabCountdownButton),
      );

      await tester.pump(const Duration(seconds: 3));
      expect(state.debugRemainingSeconds, 7);

      await tester.tap(find.byType(VocabCountdownButton));
      await tester.pump();
      expect(earlyFinishCalled, 1);
      expect(state.debugIsRunning, isFalse);

      // タップ後はタイマーが止まっているので、待っても0秒到達扱いにならない。
      await tester.pump(const Duration(seconds: 10));
      expect(zeroCalled, 0);
      expect(earlyFinishCalled, 1);
    });

    testWidgets('start()を多重に呼んでも二重にタイマーが動かない（多重起動防止）', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VocabCountdownButton(
              seconds: 5,
              onTapEarlyFinish: () {},
              onCountdownZero: () {},
            ),
          ),
        ),
      );

      final state = tester.state<VocabCountdownButtonState>(
        find.byType(VocabCountdownButton),
      );

      // 既に自動開始済みのところへさらにstart()を呼んでも、残秒がリセット
      // されたり二重に減ったりしない。
      state.start();
      state.start();
      await tester.pump(const Duration(seconds: 1));
      expect(state.debugRemainingSeconds, 4);
    });

    testWidgets('autoStart:falseなら明示的にstart()を呼ぶまで動かない', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VocabCountdownButton(
              autoStart: false,
              onTapEarlyFinish: () {},
              onCountdownZero: () {},
            ),
          ),
        ),
      );

      final state = tester.state<VocabCountdownButtonState>(
        find.byType(VocabCountdownButton),
      );
      expect(state.debugIsRunning, isFalse);
      await tester.pump(const Duration(seconds: 3));
      expect(state.debugRemainingSeconds, 10);

      state.start();
      await tester.pump(const Duration(seconds: 1));
      expect(state.debugRemainingSeconds, 9);
    });

    testWidgets('dispose時にタイマーが残らない（アンマウント後の例外なし）', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VocabCountdownButton(
              onTapEarlyFinish: () {},
              onCountdownZero: () {},
            ),
          ),
        ),
      );

      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump(const Duration(seconds: 15));
      expect(tester.takeException(), isNull);
    });
  });
}
