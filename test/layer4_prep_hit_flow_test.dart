import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:osm_gradus/localization/app_strings.dart';
import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/models/saved_scoring_result.dart';
import 'package:osm_gradus/models/scoring_models.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/services/scoring_result_storage.dart';
import 'package:osm_gradus/services/topic_speech_reader.dart';
import 'package:osm_gradus/services/tts_settings_service.dart';
import 'package:osm_gradus/views/layers/layer4_screen.dart';

const _lang = 'vi';
String _t(String key) => key.tr(_lang);

/// 「送信」「リセット」等、ダブルタップの機能ヒントが付いたボタン（Step 7）
/// はGestureDetector.onDoubleTapで単タップ判定を約300ms（kDoubleTapTimeout）
/// 保留するため、単タップとして確定させるにはこの分だけ余分にpumpする。
const _tapConfirmWait = Duration(milliseconds: 350);

const _validPrepHitJson = '''
{
  "prepStars": 4,
  "hitStars": 3,
  "prepAdvice": "結論を先に述べられていて良い構成です。",
  "hitAdvice": "質問の意図にはおおむね答えられています。"
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

SavedScoringResult _buildResult(String id) {
  final started = DateTime(2026, 1, 1, 10, 0, 0);
  return SavedScoringResult(
    id: id,
    createdAt: started,
    result: ScoringResult(
      transcriptChunks: [
        TranscriptChunk(text: 'わたしはこう考えます。', recognizedAt: started),
      ],
      fullTranscript: 'わたしはこう考えます。',
      keigo: const KeigoAnalysis(
        categories: [
          KeigoCategoryResult(category: 'teineigo', matchedExpressions: {'です'}),
        ],
        varietyScore: 1,
      ),
      complexity: const SentenceComplexityAnalysis(
        totalUnits: 1,
        complexUnitCount: 0,
        complexityRatio: 0,
      ),
      fluency: FluencyAnalysis(
        allottedSeconds: 45,
        capturedSeconds: 45,
        timeToFirstSpeechSeconds: 1,
        estimatedSpeechSeconds: 10,
        estimatedSilenceSeconds: 35,
        silenceRatio: 0.78,
        timeUtilization: 0.22,
        spokenCharacterCount: 11,
        charactersPerAllottedMinute: 14.6,
        longPauseCount: 1,
        referenceLevel: 2,
      ),
      session: SpeechSessionContext(
        allottedSeconds: 45,
        startedAt: started,
        endedAt: started.add(const Duration(seconds: 45)),
      ),
    ),
  );
}

Future<Layer4ScreenState> _pumpLayer4(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: Layer4Screen())),
  );
  await tester.pump();
  return tester.state<Layer4ScreenState>(find.byType(Layer4Screen));
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

  testWidgets('JSST採点直後は「送信」（診断アイコン）が有効になり、'
      'タップ→同意→貼り付けでPREP・的中度が同じ結果に書き足される', (WidgetTester tester) async {
    final originalUrlLauncher = UrlLauncherPlatform.instance;
    final fakeUrlLauncher = _FakeUrlLauncherPlatform();
    UrlLauncherPlatform.instance = fakeUrlLauncher;
    addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);
    _mockClipboard(tester);

    final state = await _pumpLayer4(tester);
    final result = _buildResult('r1');
    await ScoringResultStorage().save(result);
    state.debugSetEvaluatedResult(result);
    await tester.pump();

    final diagnoseIgnorePointer = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byIcon(Icons.send_rounded),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(diagnoseIgnorePointer.ignoring, isFalse);

    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, _t('同意してGoogleへ送信')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(fakeUrlLauncher.launchedUrls, hasLength(1));
    expect(find.byIcon(Icons.content_paste_go_rounded), findsOneWidget);

    await Clipboard.setData(const ClipboardData(text: _validPrepHitJson));
    await tester.tap(find.byIcon(Icons.content_paste_go_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(state.debugLastResult?.prepStars, 4);
    expect(state.debugLastResult?.hitStars, 3);
    expect(state.debugLastResult?.prepAdvice, isNotNull);
    expect(state.debugLastResult?.hitAdvice, isNotNull);

    final saved = await ScoringResultStorage().loadAll();
    expect(saved, hasLength(1));
    expect(saved.single.id, 'r1');
    expect(saved.single.prepStars, 4);
    expect(saved.single.hitStars, 3);
    expect(saved.single.hasAiEvaluation, isTrue);

    // 既にAI評価が付いた結果は、再度「送信」アイコンを出さない。
    final diagnoseIgnorePointerAfter = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byIcon(Icons.send_rounded),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(diagnoseIgnorePointerAfter.ignoring, isTrue);
  });

  testWidgets('AIの回答が解析できない形式でも、原文つきで同じ結果に保存される'
      '（結果ダイアログは出ない）', (WidgetTester tester) async {
    final originalUrlLauncher = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = _FakeUrlLauncherPlatform();
    addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);
    _mockClipboard(tester);

    final state = await _pumpLayer4(tester);
    final result = _buildResult('r2');
    await ScoringResultStorage().save(result);
    state.debugSetEvaluatedResult(result);
    await tester.pump();

    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, _t('同意してGoogleへ送信')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await Clipboard.setData(const ClipboardData(text: '日本語での自由な感想文です'));
    await tester.tap(find.byIcon(Icons.content_paste_go_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(state.debugLastResult?.hasAiEvaluation, isFalse);
    expect(
      state.debugLastResult?.aiEvaluationUnparsedResponse,
      '日本語での自由な感想文です',
    );

    final saved = await ScoringResultStorage().loadAll();
    expect(saved.single.hasAiEvaluation, isFalse);
    expect(saved.single.aiEvaluationUnparsedResponse, '日本語での自由な感想文です');
  });

  testWidgets('resetAttempt()を呼ぶと、直近の結果への「送信」対象と貼り付け待ちが解除される', (
    WidgetTester tester,
  ) async {
    final state = await _pumpLayer4(tester);
    final result = _buildResult('r3');
    state.debugSetEvaluatedResult(result);
    await tester.pump();
    expect(state.debugLastResult, isNotNull);

    await state.resetAttempt();
    await tester.pump(const Duration(seconds: 4));

    expect(state.debugLastResult, isNull);
  });
}
