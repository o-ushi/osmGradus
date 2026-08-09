import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/services/vocabulary_service.dart';
import 'package:osm_gradus/views/layers/long_article_vocab_enrich_screen.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    appPreferences = await AppPreferences.load();
    appSettings = AppSettings(appPreferences);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('autoSubmit: falseでは訳未入力の語がチェック済みで一覧表示され、'
      '自動送信はされない', (WidgetTester tester) async {
    final added = await VocabularyService().addEntry('友達', '');

    await tester.pumpWidget(
      MaterialApp(
        home: LongArticleVocabEnrichScreen(entryIds: [added.single.id]),
      ),
    );
    await tester.pump();

    expect(find.text('友達'), findsOneWidget);
    final state = tester.state<LongArticleVocabEnrichScreenState>(
      find.byType(LongArticleVocabEnrichScreen),
    );
    expect(state.debugSelectedIds, {added.single.id});

    // 同意ダイアログは自動では出ない（手動でボタンを押すまで送信しない）。
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('autoSubmit: trueでは画面表示と同時に同意ダイアログが自動で出る', (
    WidgetTester tester,
  ) async {
    final originalUrlLauncher = UrlLauncherPlatform.instance;
    final fakeUrlLauncher = _FakeUrlLauncherPlatform();
    UrlLauncherPlatform.instance = fakeUrlLauncher;
    addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);

    final added = await VocabularyService().addEntry('友達', '');

    await tester.pumpWidget(
      MaterialApp(
        home: LongArticleVocabEnrichScreen(
          entryIds: [added.single.id],
          autoSubmit: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('「戻る」で画面が閉じる', (WidgetTester tester) async {
    final added = await VocabularyService().addEntry('友達', '');

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        LongArticleVocabEnrichScreen(entryIds: [added.single.id]),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(LongArticleVocabEnrichScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(LongArticleVocabEnrichScreen), findsNothing);
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
