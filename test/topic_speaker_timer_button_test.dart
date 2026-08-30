import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/widgets/topic_speaker_timer_button.dart';

Future<void> _pump(
  WidgetTester tester, {
  required TopicSpeakerTimerPhase phase,
  VoidCallback? onTap,
  VoidCallback? onLongPress,
  Color? idleForegroundColor,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TopicSpeakerTimerButton(
          phase: phase,
          onTap: onTap ?? () {},
          onLongPress: onLongPress,
          idleForegroundColor: idleForegroundColor,
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    appPreferences = await AppPreferences.load();
    appSettings = AppSettings(appPreferences);
  });

  group('TopicSpeakerTimerButton 拡張（Step 2）', () {
    testWidgets('idle時の長押しでonLongPressが呼ばれる', (tester) async {
      var longPressed = false;
      await _pump(
        tester,
        phase: TopicSpeakerTimerPhase.idle,
        onLongPress: () => longPressed = true,
      );

      await tester.longPress(find.byType(TopicSpeakerTimerButton));
      expect(longPressed, isTrue);
    });

    testWidgets('speaking時はonLongPressが呼ばれない', (tester) async {
      var longPressed = false;
      await _pump(
        tester,
        phase: TopicSpeakerTimerPhase.speaking,
        onLongPress: () => longPressed = true,
      );

      await tester.longPress(find.byType(TopicSpeakerTimerButton));
      expect(longPressed, isFalse);
    });

    testWidgets('idleForegroundColorがidleアイコンの色に反映される', (tester) async {
      await _pump(
        tester,
        phase: TopicSpeakerTimerPhase.idle,
        idleForegroundColor: Colors.orange,
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.casino));
      expect(icon.color, Colors.orange);
    });

    testWidgets('idleForegroundColor未指定時は既定色(onAccent)のまま', (tester) async {
      await _pump(tester, phase: TopicSpeakerTimerPhase.idle);

      final icon = tester.widget<Icon>(find.byIcon(Icons.casino));
      expect(icon.color, isNot(Colors.orange));
    });
  });
}
