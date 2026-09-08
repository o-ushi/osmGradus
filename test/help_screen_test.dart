import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/localization/app_strings.dart';
import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/views/help/help_screen.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    appPreferences = await AppPreferences.load();
    appSettings = AppSettings(appPreferences);
    PackageInfo.setMockInitialValues(
      appName: 'osmGradus',
      packageName: 'com.osamushikubo.osm_gradus',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('操作の基本セクションにChrome AIのコピーボタン案内が表示される（Step 5）', (tester) async {
    appSettings.language = 'ja';
    addTearDown(() => appSettings.language = AppPreferences.defaultLanguage);

    await tester.pumpWidget(const MaterialApp(home: HelpScreen()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('help.gradus.gesture.tip4'.tr('ja')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('help.gradus.gesture.tip4'.tr('ja')), findsOneWidget);
  });
}
