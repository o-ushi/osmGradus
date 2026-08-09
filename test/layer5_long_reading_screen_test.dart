import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:osm_gradus/localization/app_strings.dart';
import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/models/long_article.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/services/pronunciation_check_storage.dart';
import 'package:osm_gradus/services/topic_speech_reader.dart';
import 'package:osm_gradus/services/tts_settings_service.dart';
import 'package:osm_gradus/views/layers/layer5_long_reading_screen.dart';

const _lang = 'vi';
String _t(String key) => key.tr(_lang);

final _article = LongArticle(
  id: 'article_1',
  title: '旅行',
  body: '友達と一緒に旅行に行きました。とても楽しかったです。',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

const _validEvaluationJson = '''
{
  "categoryEvaluations": {
    "tsu": {"score": 3, "confidence": "medium", "feedback": "a", "evidence": "c"}
  },
  "summary": "全体的に良く音読できています。"
}''';

void _mockClipboard(WidgetTester tester) {
  var clipboardText = '';
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      switch (call.method) {
        case 'Clipboard.getData':
          return {'text': clipboardText};
        case 'Clipboard.setData':
          clipboardText = (call.arguments as Map)['text'] as String? ?? '';
          return null;
        default:
          return null;
      }
    },
  );
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

Future<Layer5LongReadingScreenState> _pumpScreen(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Layer5LongReadingScreen(article: _article)),
    ),
  );
  await tester.pump();
  return tester.state<Layer5LongReadingScreenState>(
    find.byType(Layer5LongReadingScreen),
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    appPreferences = await AppPreferences.load();
    appSettings = AppSettings(appPreferences);
    ttsSettings = TtsSettingsService();
    topicSpeechReader = TopicSpeechReader(ttsSettings);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('長文の本文が全文表示され、マイクボタンは録音の構えから始まる', (WidgetTester tester) async {
    final state = await _pumpScreen(tester);

    expect(find.textContaining('友達と一緒に旅行'), findsOneWidget);
    expect(state.debugRecording, isFalse);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
  });

  testWidgets('録音中、最短15秒（pastMinRecording=false）はタップしても停止しない', (
    WidgetTester tester,
  ) async {
    final state = await _pumpScreen(tester);

    state.debugForceRecording();
    await tester.pump();
    expect(state.debugRecording, isTrue);
    expect(state.debugPastMinRecording, isFalse);

    await tester.tap(find.byIcon(Icons.mic_rounded));
    await tester.pump();

    // 15秒未満のタップは無視され、録音中のまま。
    expect(state.debugRecording, isTrue);
  });

  testWidgets('文字起こし結果が得られると送信ボタンが有効になり、送信→貼り付けで'
      'source=\'long\'として保存される', (WidgetTester tester) async {
    final originalUrlLauncher = UrlLauncherPlatform.instance;
    final fakeUrlLauncher = _FakeUrlLauncherPlatform();
    UrlLauncherPlatform.instance = fakeUrlLauncher;
    addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);
    _mockClipboard(tester);

    final state = await _pumpScreen(tester);
    state.debugCompleteWithTranscript('友達と一緒に旅行に行きました');
    await tester.pump();
    expect(state.debugTranscript, '友達と一緒に旅行に行きました');

    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, _t('同意してGoogleへ送信')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(fakeUrlLauncher.launchedUrls, hasLength(1));
    expect(find.byIcon(Icons.content_paste_go_rounded), findsOneWidget);

    await Clipboard.setData(const ClipboardData(text: _validEvaluationJson));
    await tester.tap(find.byIcon(Icons.content_paste_go_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text(_t('評価結果プレビュー')), findsOneWidget);

    final saved = await PronunciationCheckStorage().loadAll();
    expect(saved, hasLength(1));
    expect(saved.single.source, 'long');
    expect(saved.single.longArticleId, 'article_1');
    expect(saved.single.longArticleTitle, '旅行');
    expect(saved.single.questions, isNull);
    expect(saved.single.transcript, '友達と一緒に旅行に行きました');
    expect(saved.single.evaluation, isNotNull);
  });

  testWidgets('マイクの下に「戻る」ボタンは表示されない（ヘッダー「Ⅴ」再タップで戻る）', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester);

    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
  });
}
