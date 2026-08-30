import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/widgets/prep_label_row.dart';

Future<void> _pump(
  WidgetTester tester, {
  VoidCallback? onExampleTap,
  VoidCallback? onExampleLongPress,
  String? exampleHintTapText,
  String? exampleHintLongPressText,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PrepLabelRow(
          showExample: true,
          exampleIcon: Icons.list_alt_rounded,
          exampleActive: true,
          onExampleTap: onExampleTap,
          onExampleLongPress: onExampleLongPress,
          exampleHintTapText: exampleHintTapText,
          exampleHintLongPressText: exampleHintLongPressText,
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

  group('PrepLabelRow.onExampleLongPress（Step 5）', () {
    testWidgets('長押しでonExampleLongPressが呼ばれ、タップのonExampleTapとは独立している', (
      tester,
    ) async {
      var tapped = false;
      var longPressed = false;
      await _pump(
        tester,
        onExampleTap: () => tapped = true,
        onExampleLongPress: () => longPressed = true,
      );

      await tester.longPress(find.byIcon(Icons.list_alt_rounded));
      expect(longPressed, isTrue);
      expect(tapped, isFalse);
    });

    testWidgets('onExampleLongPress未指定でも既存のタップは変わらず動く', (tester) async {
      var tapped = false;
      await _pump(tester, onExampleTap: () => tapped = true);

      await tester.tap(find.byIcon(Icons.list_alt_rounded));
      expect(tapped, isTrue);
    });
  });
}
