import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:osm_gradus/localization/app_strings.dart';
import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/views/help/help_screen.dart';
import 'package:osm_gradus/views/settings/privacy_data_screen.dart';

const _sections = {
  'g_l1': 3,
  'g_l2': 3,
  'g_l3': 3,
  'g_l4': 3,
  'g_l5': 3,
  'g_vocab': 3,
  'g_prompts': 3,
  'g_dashboard': 3,
  'g_certificate': 1,
  'g_copy': 2,
  'g_hint': 1,
  'g_close': 1,
  'g_export': 2,
  'g_import': 2,
  'g_icloud': 1,
};

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
    appSettings.language = 'ja';
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 12000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: HelpScreen()));
    await tester.pumpAndSettle();
  }

  for (final lang in ['ja', 'en', 'vi']) {
    test('$lang: 各節の文言があり、手順は 3 つまでで短い', () {
      final japanese = RegExp(r'[\u3040-\u30ff\u4e00-\u9fff]');
      for (final MapEntry(key: id, value: count) in _sections.entries) {
        expect(count, lessThanOrEqualTo(3));
        for (final key in [
          'help.$id.title',
          for (var i = 1; i <= count; i++) 'help.$id.$i',
        ]) {
          final text = key.tr(lang);
          expect(text, isNot(key), reason: key);
          expect(text.length, lessThanOrEqualTo(80), reason: key);
          if (lang != 'ja') {
            expect(japanese.hasMatch(text), isFalse, reason: key);
          }
        }
      }
    });
  }

  testWidgets('操作マニュアルは無く、節は閉じて始まり、開くと番号順の手順が出る', (tester) async {
    await pump(tester);
    expect(find.byIcon(Icons.menu_book_outlined), findsNothing);
    expect(find.text('help.g_l1.1'.tr('ja')), findsNothing);

    final card = find.byKey(const ValueKey('help-section-g_l1'));
    await tester.tap(find.text('help.g_l1.title'.tr('ja')));
    await tester.pumpAndSettle();
    for (var i = 1; i <= _sections['g_l1']!; i++) {
      expect(
        find.descendant(of: card, matching: find.text('$i')),
        findsOneWidget,
      );
      expect(find.text('help.g_l1.$i'.tr('ja')), findsOneWidget);
    }

    await tester.tap(find.text('help.g_l1.title'.tr('ja')));
    await tester.pumpAndSettle();
    expect(find.text('help.g_l1.1'.tr('ja')), findsNothing);
  });

  testWidgets('プライバシーはヘルプから開く', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('help-privacy')));
    await tester.pumpAndSettle();
    expect(find.byType(PrivacyDataScreen), findsOneWidget);
  });
}
