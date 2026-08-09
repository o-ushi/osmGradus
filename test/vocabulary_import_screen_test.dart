import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/localization/app_strings.dart';
import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/views/layers/vocabulary_import_screen.dart';

const _lang = 'vi';
String _t(String key) => key.tr(_lang);

void _mockClipboard(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      switch (call.method) {
        case 'Clipboard.getData':
          return {'text': ''};
        case 'Clipboard.setData':
          return null;
        default:
          return null;
      }
    },
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
  });

  testWidgets('語彙取り込み画面の基本UIが表示される', (WidgetTester tester) async {
    _mockClipboard(tester);
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: VocabularyImportScreen()),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text(_t('語彙の取り込み')), findsWidgets);
    expect(find.text(_t('Chrome AI で開く')), findsOneWidget);
    expect(find.text(_t('取り込む')), findsOneWidget);
    expect(find.text(_t('N1レベル')), findsOneWidget);
    expect(find.text(_t('N2レベル')), findsOneWidget);
    expect(find.text(_t('N3レベル')), findsOneWidget);
  });
}
