import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

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

  test('操作マニュアルURLは言語ごとに固定のpreview先を返す', () {
    expect(
      HelpScreen.userManualUrlFor('ja'),
      'https://docs.google.com/presentation/d/'
      '${HelpScreen.userManualPresentationIdJa}/preview',
    );
    expect(
      HelpScreen.userManualUrlFor('en'),
      'https://docs.google.com/presentation/d/'
      '${HelpScreen.userManualPresentationIdEn}/preview',
    );
    expect(
      HelpScreen.userManualUrlFor('vi'),
      'https://docs.google.com/presentation/d/'
      '${HelpScreen.userManualPresentationIdVi}/preview',
    );
    expect(
      HelpScreen.userManualUrlFor('fr'),
      HelpScreen.userManualUrlFor('vi'),
    );
  });

  testWidgets('問題文の分類と一覧セクションが表示される', (tester) async {
    appSettings.language = 'ja';
    addTearDown(() => appSettings.language = AppPreferences.defaultLanguage);

    await tester.pumpWidget(const MaterialApp(home: HelpScreen()));
    await tester.pumpAndSettle();

    expect(
      find.text('help.gradus.questionPrompts.title'.tr('ja')),
      findsOneWidget,
    );
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

  testWidgets('操作マニュアルをタップすると表示言語のGoogleスライドが開く', (tester) async {
    final originalUrlLauncher = UrlLauncherPlatform.instance;
    final fakeUrlLauncher = _FakeUrlLauncherPlatform();
    UrlLauncherPlatform.instance = fakeUrlLauncher;
    addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);

    appSettings.language = 'en';
    addTearDown(() => appSettings.language = AppPreferences.defaultLanguage);

    await tester.pumpWidget(const MaterialApp(home: HelpScreen()));
    await tester.pumpAndSettle();

    expect(
      find.text('help.gradus.manual.title'.tr(appSettings.language)),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('help_user_manual')));
    await tester.pumpAndSettle();

    expect(fakeUrlLauncher.launchedUrls, [HelpScreen.userManualUrlFor('en')]);
    expect(HelpScreen.userManualUrlFor('en'), endsWith('/preview'));
  });
}

class _FakeUrlLauncherPlatform extends UrlLauncherPlatform {
  final List<String> launchedUrls = [];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrls.add(url);
    return true;
  }
}
